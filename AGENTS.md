# AGENTS.md — auth_jwt_go

Guía para agentes de IA y personas nuevas en el repositorio. Este archivo es la fuente canónica; `CLAUDE.md` lo importa y solo agrega notas específicas de Claude Code.

## Qué es este proyecto

`auth_jwt_go` es una **gema Ruby para Rails** (no es un proyecto Go, a pesar del nombre). Provee un módulo `AuthJwtGo` que se incluye en un controlador base de una API Rails para:

- **Autenticar la aplicación cliente** mediante un header `Api-Token` comparado contra `secret_key_api` (`before_action :authorized_app`).
- **Identificar al usuario** a partir de un JWT enviado en el header `Authorization: Bearer <token>` (`before_action :authorized_user`), exponiendo el helper `current_user`.
- **Emitir JWTs** con `encode_token(payload)`.
- **Decodificar un JWT de otro request** (`decoded_tenant(http_request)`), pensado para comunicación entre microservicios.

Está publicada en RubyGems como `auth_jwt_go`. Versión actual: ver `lib/auth_jwt_go/version.rb` (1.1.0). Repositorio público: https://github.com/remolacho/auth_jwt_go.

## Estructura

```
lib/auth_jwt_go.rb                                   # Módulo principal: configuración + métodos de autenticación
lib/auth_jwt_go/version.rb                           # AuthJwtGo::VERSION
lib/auth_jwt_go/authorized_user.rb                   # Objeto dinámico construido desde el payload del JWT
lib/generators/auth_jwt_go/install_generator.rb      # rails g auth_jwt_go:install  → config/initializers/init_auth_jwt.rb
lib/generators/auth_jwt_go/test_helper_generator.rb  # rails g auth_jwt_go:test_helper → spec/support/request_helpers.rb
lib/generators/auth_jwt_go/templates/                # Plantillas que copian los generadores
spec/                                                # RSpec
auth_jwt_go.gemspec, Gemfile, Rakefile               # Empaquetado y tareas
*.gem                                                # Builds históricos commiteados en la raíz (0.1.0 … 1.1.0)
```

## Cómo funciona (flujo de `lib/auth_jwt_go.rb`)

1. La app host configura la gema en un initializer:
   ```ruby
   AuthJwtGo.configure do |config|
     config.secret_key_api      = 'SECRET_API'   # requerido para authorized_app
     config.secret_key_jwt      = 'SECRET_JWT'   # requerido para firmar/verificar JWT
     config.algorithm           = 'HS256'        # opcional, default HS256
     config.class_name_model    = 'User'         # opcional; si falta se usa AuthorizedUser
     config.model_primary_key   = 'id'           # opcional, default 'id'
     config.payload_primary_key = 'user_id'      # opcional, default 'id'
   end
   ```
2. `authorized_app` compara `request.headers['Api-Token']` con `secret_key_api`. Si no coincide responde 401.
3. `authorized_user` llama a `logged_in?` → `logged_in_user` → `decoded_token`:
   - Toma `request.headers['Authorization']`, hace `split(' ')[1]` y decodifica con `JWT.decode`.
   - Si `class_name_model` está configurado, busca el registro con `Model.find_by(model_primary_key => payload[payload_primary_key])`.
   - Si no, construye un `AuthJwtGo::AuthorizedUser` con todos los campos del payload como `attr_accessor` (claves convertidas con `underscore`).
   - El resultado queda en `@current_user`. Sin token válido responde 403; cualquier otra excepción responde 500.
4. `encode_token(payload)` devuelve `{ jwt: '<token>' }`.
5. `decoded_tenant(http_request)` devuelve un `AuthorizedUser` o un hash `{ message:, error: true }`. Ojo: no es consistente con el resto (mezcla objeto y hash como retorno).
6. Métodos de módulo para usar fuera de controladores (middlewares de Sidekiq, jobs, specs de las apps), sin que la app toque la gema `jwt`:
   - `AuthJwtGo.encode(payload)` devuelve el token como string.
   - `AuthJwtGo.decode(token)` devuelve el payload como hash con claves string. Acepta el token solo o con el prefijo `Bearer `.
   - `AuthJwtGo.authorized_user_from(token)` devuelve un `AuthorizedUser`.
   - Errores: `AuthJwtGo::DecodeError`, `AuthJwtGo::ExpiredSignature` y `AuthJwtGo::VerificationError`, alias de las clases de `jwt`. Todos los métodos de instancia usan estos internamente; si cambiás cómo se firma o verifica, hacelo acá.

## Dependencias implícitas (importante)

El gemspec declara `jwt` (`>= 2.2, < 4`) como dependencia runtime y `lib/auth_jwt_go.rb` la requiere, así que las apps no necesitan agregarla a su Gemfile. El resto se asume provisto por la app host:

- `ActiveSupport` para `present?`, `presence`, `classify`, `constantize`, `underscore`.
- `Rails` para los generadores (`Rails::Generators::Base`) y para `render`/`request` dentro de controladores.

Fuera de una app Rails, `lib/auth_jwt_go.rb` se puede cargar, pero los métodos del módulo no funcionan sin esos helpers. Si agregás una dependencia nueva, declarála en el gemspec con `spec.add_dependency`.

## Comandos

```bash
bin/setup              # bundle install
bundle exec rspec      # correr specs (rake por defecto también corre spec)
bundle exec rake spec
bin/console            # IRB con la gema cargada
gem build auth_jwt_go.gemspec                 # genera auth_jwt_go-X.Y.Z.gem
gem push auth_jwt_go-X.Y.Z.gem                # publicar en RubyGems (requiere credenciales)
```

### Estado del entorno local

- `Gemfile.lock` está generado con **Bundler 2.7.2** sobre Ruby 3.4. Si ves el error `DidYouMean::SPELL_CHECKERS`, alguien volvió a generarlo con un Bundler viejo: regeneralo con `bundle _2.7.2_ install`.
- `.travis.yml` todavía apunta a Ruby 2.6.5 y no se usa.
- `lib/generators/auth_jwt_go/test_helper_generator.rb` usa `File.exists?`, que fue eliminado en Ruby 3.2. En Ruby ≥ 3.2 debe ser `File.exist?`.

## Tests

- Framework: RSpec 3 (`.rspec` carga `spec_helper` con formato documentation).
- `spec/auth_jwt_go_spec.rb` cubre `encode`, `decode`, `authorized_user_from`, `authorized_app`, `authorized_user`, `encode_token` y `decoded_tenant`.
- Los métodos de instancia se prueban incluyendo `AuthJwtGo` en una clase dummy que define `request` y `render`. `activesupport` está en el Gemfile solo para tests.
- La plantilla `templates/request_helpers.rb` muestra cómo las apps host arman tokens en sus specs (`encode_token(payload).dig(:jwt)` → `"Bearer #{jwt}"`).

## Convenciones

- **Código y README en inglés**; mensajes de commit históricamente en **español** (ej. `se agrega nueva version`).
- Ruby estándar: 2 espacios, `snake_case`, un módulo/clase por archivo bajo `lib/`.
- Versionado semántico en `lib/auth_jwt_go/version.rb`. Para publicar una versión: subir `VERSION`, `gem build`, `gem push`, commitear y taguear. Los `.gem` históricos están commiteados en la raíz; mantené esa práctica o limpiála de forma consciente, pero no borres los existentes sin consultar.
- Los tags existentes (`0.1.1-fix-message-error`, `fix-obj-auth`) vienen de ramas git-flow terminadas, no son tags de versión limpios. Hay ramas remotas `develop`, `development` y `feature/agregar-token-tenant`; `master` es la rama principal.
- Mantené compatibilidad con `required_ruby_version >= 2.3.0` salvo que se decida explícitamente subirla.

## Puntos sensibles de seguridad

- `authorized_app` compara el token de app con `eql?`; no es una comparación en tiempo constante. Si se refactoriza, usar `ActiveSupport::SecurityUtils.secure_compare`.
- `decoded_token` acepta el algoritmo configurado; nunca permitir `none` ni dejar que el algoritmo venga del token.
- `secret_key_api` y `secret_key_jwt` deben salir de variables de entorno en la app host, nunca hardcodeadas en el initializer.

## Bugs conocidos / deuda técnica

- `authorized_user` responde 403 cuando no hay token válido (semánticamente debería ser 401).
- `File.exists?` en el generador de test helper (ver arriba).

## Cómo trabajar en este repo

1. Leé `lib/auth_jwt_go.rb` completo antes de tocar la lógica; es un solo archivo de ~90 líneas y todo pasa por ahí.
2. Cualquier cambio de comportamiento público (headers, códigos HTTP, forma de los retornos) rompe apps que consumen la gema: documentalo en el README y subí la versión acorde a semver.
3. Cualquier cambio en `lib/` va acompañado de specs en `spec/auth_jwt_go_spec.rb`.
4. No publiques en RubyGems ni hagas push de tags sin confirmación explícita del dueño del repo. El proceso completo de release está en `docs/releasing.md`.
