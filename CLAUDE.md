# CLAUDE.md

@AGENTS.md

## Notas para Claude Code

- Respondé en **español** al usuario; el código, comentarios y README se mantienen en **inglés**.
- Este repo es una **gema Ruby para Rails**, no un proyecto Go. No busques `go.mod` ni asumas tooling de Go por el nombre.
- Antes de editar `lib/auth_jwt_go.rb`, leé el archivo completo: toda la lógica de autenticación vive ahí y los cambios afectan a las apps que consumen la gema.
- Corré los specs con `bundle exec rspec`. La suite debe quedar en verde después de cada cambio.
- Publicar en RubyGems (`gem push`), crear tags o hacer push a `master` requiere confirmación explícita. Hay skills `git-main-deploy` y `git-sync-main` disponibles para el flujo de ramas y tags; usalas en vez de improvisar comandos.
- Al subir versión: editar `lib/auth_jwt_go/version.rb`, actualizar el ejemplo de versión en `README.md` si corresponde, y mencionar el cambio en el mensaje de commit.
