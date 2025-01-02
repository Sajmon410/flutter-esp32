const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');

// Učitajte key.env umesto .env fajla
dotenv.config({ path: './key.env' });

const app = express();
const PORT = process.env.PORT || 5004;

app.use(cors()); // Omogućava zahteve sa drugih domena
app.use(express.json());

// Endpoint za dobijanje API ključa
app.get('/api/key', (req, res) => {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    res.json({ apiKey });
});

app.listen(PORT, () => {
    console.log(`Server je pokrenut na http://localhost:${PORT}`);

});