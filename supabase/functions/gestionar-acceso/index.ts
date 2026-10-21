import { withSupabase } from 'npm:@supabase/server@^1'

function roleCode(row: any) {
  return Array.isArray(row?.roles) ? row.roles[0]?.codigo : row?.roles?.codigo
}

function isCurrent(row: any, today: string) {
  return row?.activo !== false && (!row?.fecha_desde || row.fecha_desde <= today) && (!row?.fecha_hasta || row.fecha_hasta >= today)
}

async function findAuthUserByEmail(admin: any, email: string) {
  let page = 1
  while (page <= 10) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw error
    const users = data?.users || []
    const found = users.find((u: any) => String(u.email || '').trim().toLowerCase() === email)
    if (found) return found
    if (users.length < 1000) break
    page += 1
  }
  return null
}

async function activeRoleCodes(admin: any, personId: string, today: string) {
  const { data, error } = await admin
    .from('persona_roles')
    .select('activo,fecha_desde,fecha_hasta,roles!inner(codigo)')
    .eq('persona_id', personId)
  if (error) throw error
  return (data || []).filter((row: any) => isCurrent(row, today)).map((row: any) => roleCode(row))
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    try {
      if (req.method !== 'POST') return Response.json({ error: 'Método no permitido' }, { status: 405 })
      const body = await req.json().catch(() => ({}))
      const action = String(body?.action || '')
      const callerId = String((ctx.userClaims as any)?.id || (ctx.userClaims as any)?.sub || '')
      if (!callerId) return Response.json({ error: 'Sesión no válida' }, { status: 401 })

      if (action === 'change_own_password') {
        const newPassword = String(body?.new_password || '')
        if (newPassword.length < 8) return Response.json({ error: 'La contraseña debe tener al menos 8 caracteres' }, { status: 400 })
        const { data: authData, error: authError } = await ctx.supabaseAdmin.auth.admin.getUserById(callerId)
        if (authError || !authData?.user) return Response.json({ error: 'No se ha localizado la cuenta' }, { status: 404 })
        const appMetadata = {
          ...(authData.user.app_metadata || {}),
          must_change_password: false,
          password_changed_at: new Date().toISOString(),
        }
        const { error } = await ctx.supabaseAdmin.auth.admin.updateUserById(callerId, {
          password: newPassword,
          app_metadata: appMetadata,
        })
        if (error) throw error
        return Response.json({ ok: true })
      }

      const today = new Date().toISOString().slice(0, 10)

      const { data: callerPerson, error: callerPersonError } = await ctx.supabaseAdmin
        .from('personas').select('id').eq('auth_user_id', callerId).maybeSingle()
      if (callerPersonError || !callerPerson) return Response.json({ error: 'No se ha localizado la Persona de la sesión' }, { status: 403 })

      if (action === 'change_person_email') {
        const personaId = String(body?.persona_id || callerPerson.id)
        const newEmail = String(body?.new_email || '').trim().toLowerCase()
        if (!newEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) {
          return Response.json({ error: 'Indica un correo electrónico válido' }, { status: 400 })
        }

        const callerRoles = await activeRoleCodes(ctx.supabaseAdmin, callerPerson.id, today)
        const isAdmin = callerRoles.includes('administrador')
        let authorized = personaId === callerPerson.id || isAdmin

        if (!authorized) {
          const { data: player, error: playerError } = await ctx.supabaseAdmin
            .from('jugadores').select('id').eq('persona_id', personaId).maybeSingle()
          if (playerError) throw playerError
          if (player?.id) {
            const { data: rep, error: repError } = await ctx.supabaseAdmin
              .from('representaciones_jugador')
              .select('id')
              .eq('jugador_id', player.id)
              .eq('representante_persona_id', callerPerson.id)
              .lte('fecha_desde', today)
              .or(`fecha_hasta.is.null,fecha_hasta.gte.${today}`)
              .limit(1)
            if (repError) throw repError
            authorized = Boolean(rep?.length)
          }
        }
        if (!authorized) return Response.json({ error: 'No autorizado para cambiar el correo de esta Persona' }, { status: 403 })

        const { data: target, error: targetError } = await ctx.supabaseAdmin
          .from('personas').select('id,auth_user_id,email_contacto').eq('id', personaId).maybeSingle()
        if (targetError || !target) return Response.json({ error: 'Persona no encontrada' }, { status: 404 })
        const oldEmail = String(target.email_contacto || '').trim().toLowerCase()

        const { data: duplicates, error: duplicateError } = await ctx.supabaseAdmin
          .from('personas').select('id,auth_user_id,email_contacto').ilike('email_contacto', newEmail).neq('id', personaId).limit(1)
        if (duplicateError) throw duplicateError
        if (duplicates?.length) return Response.json({ error: 'Ese correo ya pertenece a otra Persona' }, { status: 409 })

        const existingAuth = await findAuthUserByEmail(ctx.supabaseAdmin, newEmail)
        if (existingAuth && existingAuth.id !== target.auth_user_id) {
          return Response.json({ error: 'Ese correo ya pertenece a otra cuenta de acceso' }, { status: 409 })
        }

        let authChanged = false
        if (target.auth_user_id) {
          const { data: authData, error: authReadError } = await ctx.supabaseAdmin.auth.admin.getUserById(target.auth_user_id)
          if (authReadError || !authData?.user) return Response.json({ error: 'No se ha localizado la cuenta Auth vinculada' }, { status: 404 })
          const authEmail = String(authData.user.email || '').trim().toLowerCase()
          if (authEmail !== newEmail) {
            const { error: authUpdateError } = await ctx.supabaseAdmin.auth.admin.updateUserById(target.auth_user_id, {
              email: newEmail,
              email_confirm: true,
            })
            if (authUpdateError) throw authUpdateError
            authChanged = true
          }
        }

        if (oldEmail !== newEmail) {
          const { error: personUpdateError } = await ctx.supabaseAdmin
            .from('personas').update({ email_contacto: newEmail, updated_at: new Date().toISOString() }).eq('id', personaId)
          if (personUpdateError) throw personUpdateError

          try {
            await ctx.supabaseAdmin.from('auditoria').insert({
              entidad: 'persona', entidad_id: personaId, accion: 'cambio_email', actor_auth_user_id: callerId,
              datos_nuevos: { email_anterior: oldEmail || null, email_nuevo: newEmail },
            })
          } catch (_) {}
        }

        return Response.json({ ok: true, email: newEmail, auth_updated: authChanged, unchanged: oldEmail === newEmail && !authChanged })
      }

      if (!['create_internal_user', 'invite_internal_user', 'invite_coach_user', 'get_internal_access_state', 'resend_internal_invitation'].includes(action)) {
        return Response.json({ error: 'Acción no reconocida' }, { status: 400 })
      }

      const { data: callerRoles, error: callerRolesError } = await ctx.supabaseAdmin
        .from('persona_roles')
        .select('activo,fecha_desde,fecha_hasta,roles!inner(codigo)')
        .eq('persona_id', callerPerson.id)
      if (callerRolesError) throw callerRolesError
      const isAdmin = (callerRoles || []).some((row: any) => roleCode(row) === 'administrador' && isCurrent(row, today))
      const isClub = (callerRoles || []).some((row: any) => roleCode(row) === 'club' && isCurrent(row, today))
      if (action === 'invite_coach_user') {
        if (!isAdmin && !isClub) return Response.json({ error: 'Solo Club o Administrador pueden invitar entrenadores' }, { status: 403 })
      } else if (!isAdmin) {
        return Response.json({ error: 'Solo un administrador puede crear cuentas internas' }, { status: 403 })
      }

      const personaId = String(body?.persona_id || '')
      if (!personaId) return Response.json({ error: 'Falta persona_id' }, { status: 400 })
      const redirectTo = String(body?.redirect_to || '').trim() || undefined

      const { data: person, error: personError } = await ctx.supabaseAdmin
        .from('personas')
        .select('id,auth_user_id,nombre,primer_apellido,segundo_apellido,email_contacto,activo')
        .eq('id', personaId).maybeSingle()
      if (personError || !person) return Response.json({ error: 'Persona no encontrada' }, { status: 404 })
      if (person.activo === false) return Response.json({ error: 'La Persona está inactiva' }, { status: 409 })

      const email = String(person.email_contacto || '').trim().toLowerCase()
      if (!email) return Response.json({ error: 'La Persona no tiene correo electrónico' }, { status: 400 })

      if (action === 'get_internal_access_state') {
        if (!person.auth_user_id) return Response.json({ ok: true, linked: false, email, confirmed: false })
        const { data: authData, error: authError } = await ctx.supabaseAdmin.auth.admin.getUserById(person.auth_user_id)
        if (authError || !authData?.user) return Response.json({ error: 'No se ha localizado la cuenta Auth vinculada' }, { status: 404 })
        const u: any = authData.user
        return Response.json({
          ok: true,
          linked: true,
          user_id: u.id,
          email: u.email || email,
          confirmed: Boolean(u.email_confirmed_at || u.confirmed_at),
          email_confirmed_at: u.email_confirmed_at || null,
          invited_at: u.invited_at || null,
          confirmation_sent_at: u.confirmation_sent_at || null,
          last_sign_in_at: u.last_sign_in_at || null,
        })
      }

      const { data: accessRows, error: accessError } = await ctx.supabaseAdmin
        .from('persona_roles')
        .select('activo,fecha_desde,fecha_hasta,roles!inner(codigo)')
        .eq('persona_id', personaId)
      if (accessError) throw accessError
      const internalRoles = (accessRows || [])
        .filter((row: any) => ['administrador', 'club', 'entrenador'].includes(roleCode(row)) && isCurrent(row, today))
        .map((row: any) => roleCode(row))
      if (!internalRoles.length) return Response.json({ error: 'Asigna al menos un perfil interno: Administrador, Club o Entrenador' }, { status: 409 })
      if (action === 'invite_coach_user' && !internalRoles.includes('entrenador')) return Response.json({ error: 'La Persona no tiene perfil Entrenador activo' }, { status: 409 })

      if (action === 'resend_internal_invitation') {
        if (!person.auth_user_id) return Response.json({ error: 'La Persona todavía no tiene una cuenta Auth vinculada' }, { status: 409 })
        const { data: authData, error: authError } = await ctx.supabaseAdmin.auth.admin.getUserById(person.auth_user_id)
        if (authError || !authData?.user) return Response.json({ error: 'No se ha localizado la cuenta Auth vinculada' }, { status: 404 })
        const u: any = authData.user
        if (String(u.email || '').trim().toLowerCase() !== email) return Response.json({ error: 'El correo de la Persona no coincide con el de su cuenta Auth' }, { status: 409 })
        if (u.email_confirmed_at || u.confirmed_at) return Response.json({ error: 'La cuenta ya está activada. No necesita un nuevo enlace de activación.' }, { status: 409 })
        const { error: metaError } = await ctx.supabaseAdmin.auth.admin.updateUserById(u.id, {
          app_metadata: { ...(u.app_metadata || {}), must_change_password: true, account_origin: 'club_admin_invite' },
        })
        if (metaError) throw metaError
        const { error: resetError } = await ctx.supabaseAdmin.auth.resetPasswordForEmail(email, { redirectTo })
        if (resetError) throw resetError
        return Response.json({ ok: true, user_id: u.id, email, activation_sent: true, delivery: 'recovery' })
      }

      if (person.auth_user_id) return Response.json({ ok: true, linked: true, user_id: person.auth_user_id, email: person.email_contacto, already_linked: true })

      const displayName = [person.nombre, person.primer_apellido, person.segundo_apellido].filter(Boolean).join(' ')
      let user: any = await findAuthUserByEmail(ctx.supabaseAdmin, email)
      let invitationSent = false

      if (!user) {
        const { data: invited, error: inviteError } = await ctx.supabaseAdmin.auth.admin.inviteUserByEmail(email, {
          data: { display_name: displayName, person_id: person.id, account_origin: 'club_admin' },
          redirectTo,
        })
        if (inviteError) throw inviteError
        user = invited?.user
        invitationSent = true
        if (user?.id) {
          await ctx.supabaseAdmin.auth.admin.updateUserById(user.id, {
            app_metadata: { ...(user.app_metadata || {}), must_change_password: true, account_origin: 'club_admin_invite' },
          })
        }
      }

      if (!user?.id) throw new Error('Supabase no devolvió el identificador de la cuenta')

      const { data: owner, error: ownerError } = await ctx.supabaseAdmin
        .from('personas').select('id').eq('auth_user_id', user.id).maybeSingle()
      if (ownerError) throw ownerError
      if (owner && owner.id !== person.id) {
        return Response.json({ error: 'Ese correo ya está vinculado a otra Persona. Revisa las identidades antes de continuar.' }, { status: 409 })
      }

      const { data: updated, error: updateError } = await ctx.supabaseAdmin
        .from('personas').update({ auth_user_id: user.id }).eq('id', person.id).is('auth_user_id', null).select('id').maybeSingle()
      if (updateError || (!updated && !owner)) throw updateError || new Error('No se ha podido vincular la cuenta a la Persona')

      return Response.json({
        ok: true,
        user_id: user.id,
        email,
        invitation_sent: invitationSent,
        linked_existing_account: !invitationSent,
        roles: internalRoles,
      })
    } catch (error) {
      console.error('gestionar-acceso', error)
      return Response.json({ error: error instanceof Error ? error.message : String(error) }, { status: 500 })
    }
  }),
}
