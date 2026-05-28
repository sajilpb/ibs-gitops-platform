const os = require('os');
const express = require('express');
const redis = require('redis');
const client = require('prom-client'); 

const app = express();

// Support both local development and AWS ElastiCache
const redisHost = process.env.REDIS_HOST || 'redis';
const redisPort = parseInt(process.env.REDIS_PORT, 10) || 6379;
const redisUrl = process.env.REDIS_URL || `redis://${redisHost}:${redisPort}`;
const redisClient = redis.createClient({
  url: redisUrl,
  retry_strategy: (options) => {
    if (options.error) {
      console.error('Redis retry error:', options.error);
    }

    if (options.total_retry_time > 10000) {
      return new Error('Redis retry time exhausted');
    }
    if (options.attempt > 3) {
      return undefined;
    }
    return Math.min(options.attempt * 100, 3000);
  },
  enable_offline_queue: false,
  connect_timeout: 5000,
});

// Handle Redis connection lifecycle
redisClient.on('error', (err) => {
  console.error('Redis connection error:', err);
});

redisClient.on('connect', () => {
  console.log('Redis connected at TCP level:', redisUrl);
});

redisClient.on('ready', () => {
  console.log('Redis ready:', redisUrl);
});

redisClient.on('end', () => {
  console.warn('Redis connection ended');
});

redisClient.on('reconnecting', () => {
  console.warn('Redis reconnecting...');
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
  const timeout = setTimeout(() => {
    if (!res.headersSent) {
      console.error('Redis GET timeout for /');
      res.status(504).send('Redis timeout');
    }
  }, 5000);

  redisClient.get('numVisits', function(err, numVisits) {
    clearTimeout(timeout);

    if (err) {
      console.error('Redis GET error:', err);
      return res.status(500).send('Redis error');
    }

    let numVisitsToDisplay = parseInt(numVisits, 10);
    if (isNaN(numVisitsToDisplay)) {
      numVisitsToDisplay = 0;
    }
    numVisitsToDisplay += 1;

    visitCounter.inc();

    redisClient.set('numVisits', numVisitsToDisplay, function(setErr) {
      if (setErr) {
        console.error('Redis SET error:', setErr);
      }
    });

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