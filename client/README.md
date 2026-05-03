## DAMS client (React + Vite)

### Configure API URL (fix login/signup)

- Copy `client/.env.example` to `client/.env`
- Set `VITE_API_BASE_URL` to where `server/index.php` is reachable from your browser

Common values:

- If you run PHP built-in server: `http://localhost:8000`
- If you use XAMPP/Apache with this repo under `htdocs`: `http://localhost/digital-afterlife-management-system/server`

Then restart the Vite dev server so env is picked up.
