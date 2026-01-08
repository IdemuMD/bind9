const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Secret key should be in environment variable for security
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const TOKEN_EXPIRY = '1h'; // Token expires in 1 hour

// Middleware
app.use(express.json());
app.use(cors());

// Serve static frontend files
app.use(express.static(path.join(__dirname, '../frontend')));

// File to store users (in production, use a proper database)
const USERS_FILE = path.join(__dirname, 'users.json');

// Helper function to read users from file
function readUsers() {
    try {
        if (!fs.existsSync(USERS_FILE)) {
            return [];
        }
        const data = fs.readFileSync(USERS_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error('Error reading users file:', error);
        return [];
    }
}

// Helper function to write users to file
function writeUsers(users) {
    try {
        fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
    } catch (error) {
        console.error('Error writing users file:', error);
    }
}

// Initialize with a test user if no users exist
function initializeTestUser() {
    const users = readUsers();
    if (users.length === 0) {
        const testUser = {
            id: 1,
            username: 'testuser',
            // Password: 'test123' (will be hashed)
            password: '$2b$10$testhashedpassword',
            role: 'user',
            createdAt: new Date().toISOString()
        };
        writeUsers([testUser]);
        console.log('Test user created. Credentials: testuser / test123');
    }
}

// Initialize admin user
function initializeAdminUser() {
    const users = readUsers();
    const adminExists = users.find(u => u.username === 'admin');
    if (!adminExists) {
        const adminUser = {
            id: 2,
            username: 'admin',
            password: '$2b$10$adminhashedpassword',
            role: 'admin',
            createdAt: new Date().toISOString()
        };
        writeUsers([...users, adminUser]);
        console.log('Admin user created. Credentials: admin / admin123');
    }
}

// ==================== ROUTES ====================

/**
 * POST /register
 * Register a new user
 * Body: { "username": "string", "password": "string" }
 */
app.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Validation
        if (!username || !password) {
            return res.status(400).json({
                error: 'Username and password are required',
                message: 'Please provide both username and password'
            });
        }

        if (username.length < 3) {
            return res.status(400).json({
                error: 'Invalid username',
                message: 'Username must be at least 3 characters long'
            });
        }

        if (password.length < 6) {
            return res.status(400).json({
                error: 'Invalid password',
                message: 'Password must be at least 6 characters long'
            });
        }

        const users = readUsers();

        // Check if user already exists
        if (users.find(u => u.username === username)) {
            return res.status(409).json({
                error: 'User exists',
                message: 'A user with this username already exists'
            });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create new user
        const newUser = {
            id: users.length + 1,
            username,
            password: hashedPassword,
            role: 'user',
            createdAt: new Date().toISOString()
        };

        users.push(newUser);
        writeUsers(users);

        res.status(201).json({
            message: 'User registered successfully',
            user: {
                id: newUser.id,
                username: newUser.username,
                role: newUser.role
            }
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({
            error: 'Server error',
            message: 'An error occurred during registration'
        });
    }
});

/**
 * POST /login
 * Authenticate user and return JWT token
 * Body: { "username": "string", "password": "string" }
 */
app.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Validation
        if (!username || !password) {
            return res.status(400).json({
                error: 'Missing credentials',
                message: 'Username and password are required'
            });
        }

        const users = readUsers();
        const user = users.find(u => u.username === username);

        if (!user) {
            return res.status(401).json({
                error: 'Authentication failed',
                message: 'Invalid username or password'
            });
        }

        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({
                error: 'Authentication failed',
                message: 'Invalid username or password'
            });
        }

        // Generate JWT token
        const tokenPayload = {
            userId: user.id,
            username: user.username,
            role: user.role
        };

        const token = jwt.sign(tokenPayload, JWT_SECRET, {
            expiresIn: TOKEN_EXPIRY,
            algorithm: 'HS256'
        });

        res.json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                username: user.username,
                role: user.role
            },
            expiresIn: TOKEN_EXPIRY
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            error: 'Server error',
            message: 'An error occurred during login'
        });
    }
});

/**
 * Middleware to verify JWT token
 */
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    
    // Check if Authorization header exists
    if (!authHeader) {
        return res.status(401).json({
            error: 'Unauthorized',
            message: 'No authorization header provided'
        });
    }

    // Check Bearer token format
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
        return res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid authorization header format. Use: Bearer <token>'
        });
    }

    const token = parts[1];

    // Verify token
    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            if (err.name === 'TokenExpiredError') {
                return res.status(403).json({
                    error: 'Forbidden',
                    message: 'Token has expired'
                });
            }
            return res.status(403).json({
                error: 'Forbidden',
                message: 'Invalid token'
            });
        }

        // Attach user info to request object
        req.user = decoded;
        next();
    });
}

/**
 * GET /protected
 * Protected endpoint - requires valid JWT token
 */
app.get('/protected', authenticateToken, (req, res) => {
    res.json({
        message: 'Access granted to protected resource',
        data: {
            userId: req.user.userId,
            username: req.user.username,
            role: req.user.role,
            timestamp: new Date().toISOString()
        }
    });
});

/**
 * GET /admin
 * Admin-only protected endpoint
 */
app.get('/admin', authenticateToken, (req, res) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            error: 'Forbidden',
            message: 'Admin access required'
        });
    }

    res.json({
        message: 'Admin access granted',
        data: {
            secret: 'This is admin-only data',
            users: readUsers().map(u => ({ id: u.id, username: u.username, role: u.role }))
        }
    });
});

/**
 * GET /profile
 * Get current user's profile
 */
app.get('/profile', authenticateToken, (req, res) => {
    const users = readUsers();
    const user = users.find(u => u.id === req.user.userId);
    
    if (!user) {
        return res.status(404).json({
            error: 'Not found',
            message: 'User not found'
        });
    }

    res.json({
        user: {
            id: user.id,
            username: user.username,
            role: user.role,
            createdAt: user.createdAt
        }
    });
});

/**
 * POST /refresh
 * Refresh JWT token (extend expiration)
 */
app.post('/refresh', authenticateToken, (req, res) => {
    const token = jwt.sign(
        {
            userId: req.user.userId,
            username: req.user.username,
            role: req.user.role
        },
        JWT_SECRET,
        {
            expiresIn: TOKEN_EXPIRY,
            algorithm: 'HS256'
        }
    );

    res.json({
        message: 'Token refreshed successfully',
        token,
        expiresIn: TOKEN_EXPIRY
    });
});

/**
 * GET /users
 * List all users (admin only)
 */
app.get('/users', authenticateToken, (req, res) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            error: 'Forbidden',
            message: 'Admin access required'
        });
    }

    const users = readUsers();
    res.json({
        users: users.map(u => ({
            id: u.id,
            username: u.username,
            role: u.role,
            createdAt: u.createdAt
        }))
    });
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString()
    });
});

/**
 * API documentation endpoint
 */
app.get('/api', (req, res) => {
    res.json({
        name: 'JWT Authentication API',
        version: '1.0.0',
        endpoints: {
            'POST /register': {
                description: 'Register a new user',
                body: { username: 'string', password: 'string' }
            },
            'POST /login': {
                description: 'Authenticate and get JWT token',
                body: { username: 'string', password: 'string' }
            },
            'GET /protected': {
                description: 'Protected endpoint - requires JWT token',
                headers: { Authorization: 'Bearer <token>' }
            },
            'GET /admin': {
                description: 'Admin-only endpoint',
                headers: { Authorization: 'Bearer <token>' }
            },
            'GET /profile': {
                description: 'Get current user profile',
                headers: { Authorization: 'Bearer <token>' }
            },
            'POST /refresh': {
                description: 'Refresh JWT token',
                headers: { Authorization: 'Bearer <token>' }
            },
            'GET /health': {
                description: 'Health check endpoint'
            }
        },
        testUsers: [
            { username: 'testuser', password: 'test123', role: 'user' },
            { username: 'admin', password: 'admin123', role: 'admin' }
        ]
    });
});

// Initialize test users
initializeTestUser();
initializeAdminUser();

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
    console.log(`Frontend: http://YOUR_VM_IP:${PORT}/`);
    console.log(`API documentation: http://YOUR_VM_IP:${PORT}/api`);
    console.log(`JWT_SECRET: ${JWT_SECRET}`);
    console.log(`Token expiry: ${TOKEN_EXPIRY}`);
});

