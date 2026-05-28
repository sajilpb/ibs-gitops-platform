const os = require('os');
const express = require('express');
const redis = require('redis');
const client = require('prom-client'); 

const app = express();

// Support both local development and AWS ElastiCache
const redisUrl = process.env.REDIS_URL || 'redis://redis:6379';
const redisClient = redis.createClient({
  url: redisUrl
});

// Handle Redis connection errors
redisClient.on('error', (err) => {
  console.error('Redis connection error:', err);
});

redisClient.on('connect', () => {
  console.log('Connected to Redis:', redisUrl);
});

// ----- 1. PROMETHEUS METRICS SETUP -----
const register = new client.Registry();
client.collectDefaultMetrics({ register }); 

// A. CUSTOM COUNTER (HTTP Requests)
// We use 'labelNames' to track Method (GET/POST) and Status Code (200/404/500)
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});
register.registerMetric(httpRequestCounter);

// B. CUSTOM GAUGE (Memory Usage)
// While default metrics catch this, here is how you manually create a Gauge
const memoryUsageGauge = new client.Gauge({
  name: 'custom_nodejs_heap_used_bytes',
  help: 'Current heap memory usage in bytes',
});
register.registerMetric(memoryUsageGauge);

// ------------------------------------

// ----- 2. MIDDLEWARE (The Magic Part) -----
// This runs before EVERY request to track metrics automatically
app.use((req, res, next) => {
  // Update the Gauge with current memory snapshot
  const used = process.memoryUsage().heapUsed;
  memoryUsageGauge.set(used); // <--- Setting the Gauge value

  // Listen for the response to finish to record the Status Code
  res.on('finish', () => {
    // Increment the Counter with Labels
    httpRequestCounter.inc({
      method: req.method, 
      route: req.path, 
      status_code: res.statusCode
    });
  });

  next();
});
// ------------------------------------------

// Custom counter for website visits (Business Logic)
const visitCounter = new client.Counter({
  name: 'website_visits_total',
  help: 'Total number of website visits counted via Redis',
});
register.registerMetric(visitCounter);


// Route for the main page
app.get('/', function(req, res) {
  redisClient.get('numVisits', function(err, numVisits) {
    let numVisitsToDisplay = parseInt(numVisits) + 1;
    if (isNaN(numVisitsToDisplay)) {
      numVisitsToDisplay = 1;
    }

    visitCounter.inc(); 
    redisClient.set('numVisits', numVisitsToDisplay);

    res.send(`${os.hostname()}: Number of visits is: ${numVisitsToDisplay}`);
  });
});

// /metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(5000, function() {
  console.log('Web application is listening on port 5000');
});