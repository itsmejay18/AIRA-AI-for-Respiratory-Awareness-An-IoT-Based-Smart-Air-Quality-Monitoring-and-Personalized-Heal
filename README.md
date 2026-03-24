# AIRA (AI for Respiratory Awareness): An IoT-Based Smart Air Quality Monitoring and Personalized Health Advisory System

AIRA is an IoT and AI-driven platform designed to monitor air quality in real time and provide personalized health advisories that help communities respond proactively to pollution-related risks.

## Project Information

- Project: AIRA (AI for Respiratory Awareness): An IoT-Based Smart Air Quality Monitoring and Personalized Health Advisory System
- Proponents: Radz Vincent L. Minoza, Jay J. Ababon, Maria Azelea Jorillo, Arian Mae G. Estrera, and Hannah Tagalog D. Melendres
- Faculty Adviser: Prof. Lilian Guia B. Burgos
- Institution: Davao del Sur State College
- Track: Public Health & Telemedicine

## Abstract

Air pollution is an increasing public health concern in the Philippines, particularly in rapidly urbanizing areas such as Metro Manila, Davao City, and Cebu City. Emissions from transportation, industrial activities, and open waste burning contribute to elevated levels of particulate matter (PM2.5 and PM10), which are linked to respiratory diseases, cardiovascular conditions, and reduced quality of life. Despite existing monitoring efforts, access to localized, real-time, and personalized air quality information remains limited, especially in vulnerable and underserved communities.

This project proposes AIRA (AI for Respiratory Awareness), an intelligent system that integrates Internet of Things (IoT), artificial intelligence (AI), and mobile technologies to address this gap. AIRA utilizes low-cost IoT sensors to collect real-time environmental data, including particulate matter, gas concentrations, temperature, and humidity. These data are transmitted to a cloud-based platform, where AI models perform air quality forecasting, anomaly detection, and health risk classification.

The system incorporates user-specific factors such as age, medical history, and activity level to generate personalized health risk assessments and actionable recommendations. Through a mobile application, users can access real-time air quality updates, predictive alerts, and tailored health advisories to support informed decision-making.

By combining environmental monitoring with AI-driven healthcare insights, AIRA empowers Filipino communities to take proactive measures against pollution-related risks. The proposed system contributes to strengthening public health resilience, supporting data-driven policy, and advancing accessible digital health solutions in the Philippines.

## Core Capabilities

- Real-time air quality monitoring using IoT sensors
- Cloud-connected environmental data collection and storage
- AI-based air quality forecasting and anomaly detection
- Personalized health risk assessment based on user context
- Mobile access to live updates, alerts, and health advisories

## Screenshots

<p align="center">
  <img src="ScreenShots/Screenshot%20%28188%29.png" alt="AIRA mobile app screenshot 1" width="260" />
  <img src="ScreenShots/Screenshot%20%28190%29.png" alt="AIRA mobile app screenshot 2" width="260" />
</p>

<p align="center">
  <img src="ScreenShots/Screenshot%20%28191%29.png" alt="AIRA mobile app screenshot 3" width="260" />
  <img src="ScreenShots/Screenshot%20%28192%29.png" alt="AIRA mobile app screenshot 4" width="260" />
</p>

<p align="center">
  <img src="ScreenShots/Screenshot%20%28193%29.png" alt="AIRA mobile app screenshot 5" width="260" />
  <img src="ScreenShots/Screenshot%20%28194%29.png" alt="AIRA mobile app screenshot 6" width="260" />
</p>

<p align="center">
  <img src="ScreenShots/Screenshot%20%28195%29.png" alt="AIRA mobile app screenshot 7" width="260" />
</p>

## Repository Structure

- [lib](./lib): Flutter mobile application source code
- [backend](./backend): Backend services and API components
- [firmware](./firmware): IoT firmware and device-side logic
- [supabase](./supabase): Database schema and seed files
- [docs](./docs): Supporting project documentation

## Local Setup

1. Install Flutter stable and the required platform toolchains.
2. Copy `.env.example` to `.env`.
3. Set the environment values for `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `AI_BASE_URL`.
4. Apply the database setup files in [supabase/schema.sql](./supabase/schema.sql).
5. Optionally load sample data from [supabase/seed.sql](./supabase/seed.sql).
6. Install backend dependencies:

```bash
pip install -r backend/requirements.txt
```

7. Start the backend service:

```bash
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

8. Run the Flutter application:

```bash
flutter pub get
flutter run
```

## Project Resources

- [backend/README.md](./backend/README.md)
- [docs/iot_payload.md](./docs/iot_payload.md)
- [firmware/esp32_http_sender/esp32_http_sender.ino](./firmware/esp32_http_sender/esp32_http_sender.ino)
- [supabase/schema.sql](./supabase/schema.sql)
- [supabase/seed.sql](./supabase/seed.sql)
- [supabasetable.txt](./supabasetable.txt)
