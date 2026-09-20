const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const express = require('express');
const cookieParser = require('cookie-parser');
const mainRoutes = require('./routes/mainRoutes');
const apiRoutes = require('./routes/apiRoutes');
const appRoutes = require('./routes/appRoutes');
const cryptoMiddleware = require('./admin/middlewares/cryptoMiddleware');
const app = express();

// Middleware Setup
app.use(cookieParser());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(express.static(path.join(__dirname, 'public')));
app.use(cryptoMiddleware);

// View engine
app.set('trust proxy', true);
app.set('view engine', 'ejs');
app.set('views', [
  path.join(__dirname, 'views'),
  path.join(__dirname, 'admin/views'),
  path.join(__dirname, 'battle-arena/views'),
]);

const appTrackingRoutes = require('./routes/modules/appTrackingRoutes');
app.use(appTrackingRoutes);

app.use('/api', apiRoutes);
app.use('/api', appRoutes);
app.use('/', mainRoutes);

// 404
app.use((_, res) => {
  res.status(404).send('404 Page Not Found');
});

// Start server
const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log(`Server running at http://admin.localhost:${PORT}`);
});

// Load Cron Jobs
require('./admin/cron/hourlyNotificationCron');