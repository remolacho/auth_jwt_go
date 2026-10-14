# Publicar una nueva versión de auth_jwt_go

Guía para liberar una versión nueva de la gema en [RubyGems](https://rubygems.org/gems/auth_jwt_go) y dejar el repositorio consistente.

## Resumen rápido

```bash
# 1. Cambios listos y mergeados en master
git checkout master && git pull origin master

# 2. Subir la versión
$EDITOR lib/auth_jwt_go/version.rb          # VERSION = "X.Y.Z"

# 3. Construir el paquete
gem build auth_jwt_go.gemspec               # genera auth_jwt_go-X.Y.Z.gem

# 4. Commit + tag
git add lib/auth_jwt_go/version.rb auth_jwt_go-X.Y.Z.gem
git commit -m "se agrega nueva version X.Y.Z"
git tag vX.Y.Z

# 5. Publicar
gem push auth_jwt_go-X.Y.Z.gem
git push origin master --tags
```

## Requisitos previos

- **Cuenta de RubyGems con permisos de owner** sobre `auth_jwt_go`. Verificar con:
  ```bash
  gem owner auth_jwt_go
  ```
- **Credenciales locales.** `gem push` lee la API key de `~/.local/share/gem/credentials`. Ver [Configurar la API key](#configurar-la-api-key-una-vez-por-pc).
- **Acceso de escritura** al repositorio `git@github.com:remolacho/auth_jwt_go.git`.

## Configurar la API key (una vez por PC)

La gema pertenece a la cuenta `remolacho` de RubyGems (jonathangrh.25@gmail.com). Para publicar hace falta una API key de esa cuenta guardada en la PC.

1. Entrar a https://rubygems.org con la cuenta `remolacho` y crear una key en https://rubygems.org/profile/api_keys con el permiso `push_rubygem`.
2. Guardarla en el archivo de credenciales sin que quede en el historial del shell:
   ```bash
   mkdir -p ~/.local/share/gem
   read -s "KEY?Pegá la API key: " && echo     # zsh; en bash: read -s -p "Pegá la API key: " KEY
   printf -- "---\n:rubygems_api_key: %s\n" "$KEY" > ~/.local/share/gem/credentials
   chmod 600 ~/.local/share/gem/credentials    # obligatorio, si no gem push lo rechaza
   unset KEY
   ```
   El archivo queda así:
   ```yaml
   ---
   :rubygems_api_key: rubygems_xxxxxxxx
   ```
3. Verificar:
   ```bash
   gem owner auth_jwt_go
   # Owners for gem: auth_jwt_go
   # - remolacho
   ```
   Si responde 401, la key está mal guardada o no tiene permiso `push_rubygem`.

Alternativa sin guardar nada en disco: `GEM_HOST_API_KEY=rubygems_xxx gem push auth_jwt_go-X.Y.Z.gem`.

## Paso a paso

### 1. Partir desde master actualizado

Los cambios se desarrollan en ramas (`feature/...`, `develop`) y se integran a `master` vía PR o `git flow ... finish`. Una versión siempre se construye desde `master` limpio:

```bash
git checkout master
git pull origin master
git status          # debe estar limpio
```

### 2. Elegir el número de versión

Seguir [versionado semántico](https://semver.org/lang/es/):

| Cambio | Ejemplo | Qué subir |
|---|---|---|
| Corrección sin cambiar comportamiento público | arreglar un mensaje de error | parche: 1.0.3 → 1.0.4 |
| Funcionalidad nueva compatible | nuevo método opcional, nueva opción de config | menor: 1.0.3 → 1.1.0 |
| Cambio incompatible para las apps que usan la gema | cambiar headers, códigos HTTP o la forma de los retornos | mayor: 1.0.3 → 2.0.0 |

Revisar versiones ya publicadas para no repetir un número (RubyGems no permite reutilizarlo, ni siquiera tras un `yank`):

```bash
gem list auth_jwt_go --remote --all
```

### 3. Actualizar la versión

Editar `lib/auth_jwt_go/version.rb`:

```ruby
module AuthJwtGo
  VERSION = "X.Y.Z"
end
```

Si el cambio es menor o mayor, actualizar también el ejemplo de instalación del `README.md` (`gem 'auth_jwt_go', '~> X.Y.0'`) y documentar cualquier opción nueva en la sección de uso.

### 4. Verificar antes de construir

```bash
bundle exec rspec
```

La suite tiene que pasar completa.

Probar la gema en una app Rails real apuntando al código local antes de publicar:

```ruby
# Gemfile de la app consumidora
gem 'auth_jwt_go', path: '/ruta/a/auth_jwt_go'
```

### 5. Construir el .gem

```bash
gem build auth_jwt_go.gemspec
```

Esto genera `auth_jwt_go-X.Y.Z.gem` en la raíz.

Revisar qué archivos entran y que `jwt` aparezca como dependencia:

```bash
gem spec auth_jwt_go-X.Y.Z.gem files
gem spec auth_jwt_go-X.Y.Z.gem dependencies
```

> Hasta la 1.0.3 el gemspec empaquetaba los `.gem` anteriores commiteados en la raíz, y cada versión pesaba el doble que la previa. Las versiones actuales de RubyGems directamente se niegan a construirlo ("contains itself"). Desde la 1.1.0 el gemspec excluye `*.gem`, `docs/`, `bin/`, `.idea/` y `.ruby-lsp/`, y el paquete pesa unos 12 KB.

### 6. Commit y tag

La convención histórica es commitear el `.gem` junto con el cambio de versión y escribir el mensaje en español:

```bash
git add lib/auth_jwt_go/version.rb README.md auth_jwt_go-X.Y.Z.gem
git commit -m "se agrega nueva version X.Y.Z"
git tag vX.Y.Z
```

Los tags existentes (`0.1.1-fix-message-error`, `fix-obj-auth`) son nombres de ramas git-flow, no versiones. A partir de ahora conviene usar `vX.Y.Z` para poder ubicar el código exacto de cada release.

### 7. Publicar en RubyGems

```bash
gem push auth_jwt_go-X.Y.Z.gem
```

Si la cuenta tiene MFA activado, pedirá el código OTP. Confirmar que aparece en https://rubygems.org/gems/auth_jwt_go/versions.

### 8. Subir a GitHub

```bash
git push origin master
git push origin vX.Y.Z
```

Si se trabaja con git-flow, mergear también `master` en `develop` para que no queden desfasadas.

## Atajo con Bundler

El `Rakefile` carga `bundler/gem_tasks`, que trae una tarea que hace build, tag `vX.Y.Z`, push a git y push a RubyGems en un solo paso:

```bash
bundle exec rake release
```

Requiere el árbol git limpio y que la versión del `version.rb` aún no tenga tag. Deja el `.gem` en `pkg/` (ignorado por git), así que no sigue la convención de commitear el `.gem` en la raíz.

## Si algo sale mal

- **Se publicó una versión rota.** Retirarla con `gem yank auth_jwt_go -v X.Y.Z` y publicar una versión de parche corregida. El número retirado no se puede volver a usar.
- **`gem push` responde que la versión ya existe.** Subir el número en `version.rb`, reconstruir y volver a publicar.
- **`gem push` responde 401 o "Access Denied".** La API key no existe o la cuenta no es owner. Ejecutar `gem signin` o pedir a un owner actual que agregue la cuenta con `gem owner auth_jwt_go --add correo@ejemplo.com`.

## Historial de versiones

| Versión | Fecha | Cambio principal |
|---|---|---|
| 1.1.0 | 2026-10-14 | `jwt` pasa a ser dependencia de la gema. Nuevos `AuthJwtGo.encode`, `AuthJwtGo.decode`, `AuthJwtGo.authorized_user_from` y alias de errores. Gemspec deja de empaquetar los `.gem` |
| 1.0.3 | 2021-10-07 | Ajuste en `lib/auth_jwt_go.rb` |
| 1.0.2 | 2021-10-07 | `AuthorizedUser` pasa a ser mutable (`attr_accessor`) |
| 1.0.1 | 2020-10-08 | Mensajes descriptivos en las excepciones de JWT |
| 1.0.0 | 2020-07-30 | `decoded_tenant` lee y decodifica el header del tenant |
| 0.1.1 – 0.1.4 | 2020-07-30 | Nuevo método para tenant y correcciones |
| 0.1.0 | 2020-07 | Versión inicial |
