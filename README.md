# Used Vehicle Showroom

A free, mobile-friendly website template for small used-vehicle dealers. Customers browse bikes, calculate EMI, save favourites and send enquiries. The owner manages stock from a hidden admin panel. It is a single `index.html` file with a [Supabase](https://supabase.com) backend, and it can be hosted for free on Netlify.

> **Status:** small, early-stage project. It is currently used by local dealerships in Maharashtra, India. Feedback and pull requests are welcome.

<!-- Add screenshots here -->
<!-- ![Showroom on mobile](docs/screenshots/mobile.png) -->
<!-- ![Admin panel](docs/screenshots/admin.png) -->

## Features

**For customers**
- Showroom with search, filters (bike type, fuel, transmission, price slider) and sorting
- Photo gallery per bike, loaded as small thumbnails for fast browsing
- EMI calculator (down payment, interest rate, tenure)
- Wishlist and side-by-side compare (up to 3 bikes)
- Sign in / register, so the wishlist is saved across devices
- Enquiry / test-ride request form
- Marathi/English-friendly layout

**For the owner (admin panel)**
- Hidden login: tap the logo 3 times, then sign in with the owner email and password
- Add, edit and delete bikes with multiple photos (compressed in the browser before upload)
- Inline price and status editing (Available / Reserved / Sold)
- Private purchase and refurbishment cost, with profit insights
- Customers, wishlists and enquiries list with status tracking
- CSV export, password change, and auto-lock when idle

## Tech stack

- Plain HTML, CSS and JavaScript (no build step), styled with Tailwind CSS (CDN)
- Supabase: Postgres database, Auth, Storage and row-level security
- Netlify (or any static host)

## Quick start

1. **Create a Supabase project** at [supabase.com](https://supabase.com) (the free plan is enough to start).
2. **Create the database:** open *SQL Editor*, paste the contents of `supabase/schema.sql` and run it. Optionally run `supabase/sample_data.sql` to add sample bikes.
3. **Create the owner account:** go to *Authentication → Users → Add user*, enter the owner's email and a strong password, and tick *Auto Confirm User*. Then run this in the SQL Editor, using the same email:
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'OWNER_EMAIL_HERE';
   ```
4. **Add your project keys** in `index.html` (near the top of the script):
   ```js
   const SUPABASE_URL = "YOUR_SUPABASE_URL";
   const SUPABASE_KEY = "YOUR_PUBLISHABLE_KEY";   // the public "anon / publishable" key
   ```
   Both values are in *Project Settings → API*.
5. **Deploy:** drag the folder with `index.html` onto [Netlify Drop](https://app.netlify.com/drop), or connect this repository to Netlify.
6. **Log in as owner:** open the site, tap the logo 3 times, and sign in.

## Security

- The publishable key in `index.html` is meant to be public. The real protection is **row-level security** in `supabase/schema.sql`:
  - Anyone can read bikes. Only the owner can add, edit or delete them.
  - Purchase costs, customer lists and enquiries can be read only by the owner.
  - Customers can read and change only their own profile and wishlist.
  - Enquiries can be created by anyone but not read or changed.
- **Never put the `service_role` / secret key in `index.html` or in this repository.**
- Use a strong owner password. The admin panel auto-locks when idle and when the tab is in the background.
- The "tap the logo 3 times" trigger only hides the admin button. It is not a security measure on its own.

## Good to know

**Free Supabase projects pause after inactivity.** A project with no database activity for about a week is paused, and the site then shows an error until you resume it in the dashboard. Regular visitors usually keep it awake. To be safe, set up a free scheduled request (for example on cron-job.org) that calls:
```
GET https://YOUR_PROJECT.supabase.co/rest/v1/bikes?select=id&limit=1
Header: apikey: YOUR_PUBLISHABLE_KEY
```
Run it once a day.

**ISP blocking in India.** In 2026, some Indian internet providers blocked `*.supabase.co` for a period. If customers see "Failed to fetch", try a different network or DNS (for example 1.1.1.1). For a permanent fix, route Supabase requests through your own domain, for example with a Cloudflare Worker proxy.

## Customize

- **Name and logo:** edit the header and hero text in `index.html` and replace the logo image.
- **Bike types, fuel and options:** edit the filter and form option lists in `index.html`, and the matching checks in `supabase/schema.sql`.
- **EMI defaults:** change the default interest rate and tenure in the EMI section of `index.html`.
- **Contact details:** replace the phone number, address and opening hours with your own.

## Project structure

```
index.html                  the whole website
supabase/
  schema.sql                tables, security rules, storage policies
  sample_data.sql           optional sample bikes
docs/screenshots/           screenshots for this README
README.md
LICENSE
```

## Roadmap ideas

- Mobile-first redesign with more animation
- Vehicle categories beyond bikes (cars, commercial vehicles)
- Short video / reels per vehicle
- "Sell your vehicle" form for sellers
- Proxy setup guide for blocked networks

## Contributing

Issues and pull requests are welcome. For larger changes, please open an issue first to discuss the idea.

## License

[MIT](LICENSE)
