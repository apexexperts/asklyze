# Oracle APEX AI Dashboard Builder 🚀

An intelligent, AI-powered dashboard generation system built on Oracle APEX that transforms natural language questions into comprehensive business intelligence dashboards with real-time data visualizations.

![Oracle APEX](https://img.shields.io/badge/Oracle%20APEX-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![PL/SQL](https://img.shields.io/badge/PL%2FSQL-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)

## 🌟 Features

### Core Capabilities
- **Natural Language to Dashboard**: Convert business questions into fully-functional dashboards
- **AI-Powered SQL Generation**: Automatic SQL query generation using OpenAI GPT models
- **Smart Chart Selection**: AI automatically selects optimal chart types based on data patterns
- **Real-time Data Visualization**: Support for multiple chart types including bar, line, area, pie, donut, and maps
- **KPI Generation**: Automatic key performance indicator extraction and display
- **Multi-language Support**: AI responds in the same language as the user's question

### Technical Features
- **Schema-Aware AI**: Dynamically reads database schema for accurate SQL generation
- **Intelligent Data Mapping**: Automatic column-to-chart axis mapping
- **Session Management**: Persistent chat and dashboard history
- **Progressive Loading**: Smooth skeleton loaders and progress indicators
- **Responsive Design**: Mobile-friendly interface with adaptive layouts
- **Error Recovery**: Fallback mechanisms for AI failures

## 📁 Project Structure

```
├── Database Objects/
│   ├── tables.sql                     # Core database tables
│   ├── AACU_F.sql                    # User authentication function
│   └── packages/
│       ├── MYQUERY_DASHBOARD_AI_PKG.sql   # Main AI dashboard generation package
│       └── MYQUERY_SMART_QUERY_PKG.sql    # Query generation and management package
│
├── APEX Processes/
│   ├── DASH_PLAN.sql                 # Dashboard planning process
│   ├── DASH_CREATE_BLOCKS.sql        # Widget creation process
│   ├── DASH_GEN_OVERVIEW.sql         # Overview generation
│   ├── DASH_GEN_KPIS.sql            # KPI generation
│   ├── DASH_GEN_CHART.sql           # Chart generation
│   ├── DASH_GEN_INSIGHTS.sql        # Insights generation
│   ├── DASH_GEN_SUMMARY.sql         # Summary generation
│   ├── DASH_FINALIZE.sql            # Dashboard finalization
│   ├── GET_DASH_META.sql            # Dashboard metadata retrieval
│   ├── GET_SIDE_MENU.sql            # Navigation menu generation
│   └── RUN_CHART_SQL.sql            # Chart SQL execution
│
└── JavaScript/
    ├── dashboard.js                   # Main dashboard UI controller
    └── Execute.js                     # Initialization and navigation
```

## 🗄️ Database Schema

### Core Tables

#### DASHBOARDS
Stores dashboard metadata and configuration
- `ID` - Primary key
- `NAME` - Dashboard title
- `DESCRIPTION` - Dashboard description/summary
- `OWNER_USER_ID` - Dashboard owner
- `IS_PUBLIC` - Public/private flag
- `CREATED_AT/UPDATED_AT` - Timestamps

#### WIDGETS
Stores individual dashboard components
- `ID` - Primary key
- `DASHBOARD_ID` - Parent dashboard reference
- `TITLE` - Widget title
- `CHART_TYPE` - Visualization type (BAR, LINE, PIE, etc.)
- `SQL_QUERY` - Generated SQL query
- `DATA_MAPPING` - Column to chart axis mapping
- `VISUAL_OPTIONS` - Chart configuration JSON
- `GRID_X/Y/W/H` - Layout positioning

#### SMART_QUERY
Stores query history and chat sessions
- `ID` - Primary key
- `QUERY_NAME` - Auto-generated query title
- `QUERY_SOURCE` - SQL query text
- `CHAT_SUMMARY` - AI-generated explanation
- `CREATED_BY` - User identifier

#### SYS_USERS
User authentication and access control
- `USER_ID` - Primary key
- `USER_NAME` - Username
- `USER_PASSWORD` - Encrypted password
- `USER_ACCESS` - Access level flag

## 🔧 Installation

### Prerequisites
- Oracle Database 19c or higher
- Oracle APEX 21.1 or higher
- OpenAI API credentials
- ApexCharts library
- Leaflet.js (for map visualizations)

### Step 1: Database Setup

```sql
-- 1. Create the workspace schema
CREATE USER WKSP_AI IDENTIFIED BY your_password;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO WKSP_AI;
GRANT UNLIMITED TABLESPACE TO WKSP_AI;

-- 2. Run table creation scripts
@tables.sql

-- 3. Create authentication function
@AACU_F.sql

-- 4. Install PL/SQL packages
@MYQUERY_DASHBOARD_AI_PKG.sql
@MYQUERY_SMART_QUERY_PKG.sql
```

### Step 2: APEX Application Setup

1. **Import APEX Application**
   - Create new application or import existing
   - Set application ID and workspace

2. **Configure Web Credentials**
   - Navigate to Shared Components → Web Credentials
   - Create credential: `credentials_for_ai_services`
   - Add OpenAI API endpoint and authentication

3. **Create Application Items**
   ```
   P0_DATABASE_SCHEMA - Database schema name
   P3_QUESTION - User's natural language question
   P3_PLAN_JSON - Dashboard planning JSON
   P3_DASH_ID - Current dashboard ID
   ```

4. **Create AJAX Callback Processes**
   - Add all DASH_* processes as AJAX callbacks
   - Set process points to "Ajax Callback"

### Step 3: Configure OpenAI Integration

```sql
-- Update the package with your OpenAI configuration
BEGIN
  -- Set default model (update as needed)
  -- Current: gpt-4o-mini, gpt-5-2025-08-07
  NULL;
END;
```

### Step 4: JavaScript Integration

1. **Include JavaScript files**
   ```html
   <!-- In Page Header -->
   <script src="#APP_IMAGES#dashboard.js"></script>
   <script src="#APP_IMAGES#Execute.js"></script>
   ```

2. **Include required libraries**
   ```html
   <!-- ApexCharts -->
   <script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
   
   <!-- Leaflet for maps -->
   <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
   <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
   ```

## 🚀 Usage

### Creating a Dashboard

1. **Natural Language Input**
   ```
   "Show me monthly sales trends with top performing products"
   "Analyze customer acquisition costs by channel"
   "Display regional performance metrics for Q4"
   ```

2. **Dashboard Generation Flow**
   - User enters question → AI plans layout → Creates widgets → Generates SQL
   - Fetches data → Renders charts → Adds insights → Finalizes dashboard

### API Workflow

```javascript
// Initiate dashboard creation
window.runDashboardBuilder();

// Process flow:
// 1. DASH_PLAN - Plans dashboard structure
// 2. DASH_CREATE_BLOCKS - Creates widget placeholders
// 3. DASH_GEN_OVERVIEW - Generates overview text
// 4. DASH_GEN_KPIS - Creates KPI metrics
// 5. DASH_GEN_CHART - Generates chart configurations
// 6. DASH_GEN_INSIGHTS - Extracts business insights
// 7. DASH_FINALIZE - Normalizes and positions widgets
```

## 🎨 Customization

### Chart Types
```javascript
// Supported chart types
const CHART_TYPES = [
  'BAR',      // Bar charts
  'LINE',     // Line graphs
  'AREA',     // Area charts
  'PIE',      // Pie charts
  'DONUT',    // Donut charts
  'TABLE',    // Data tables
  'KPI',      // Key metrics
  'MAP',      // Geographic maps
  'SCATTER'   // Scatter plots
];
```

### Color Palettes
```javascript
// Customize chart colors
const PALETTE_BANK = [
  ["#2563eb"], // Blue
  ["#16a34a"], // Green
  ["#f97316"], // Orange
  ["#dc2626"], // Red
  ["#9333ea"], // Purple
];
```

### AI Model Configuration
```sql
-- Change AI model
c_default_model CONSTANT VARCHAR2(100) := 'gpt-4o-mini';

-- Adjust temperature for creativity
temperature => 0.2  -- Lower = more deterministic
```

## 🔐 Security

- **SQL Injection Prevention**: All generated SQL is validated and parameterized
- **Schema Isolation**: AI only accesses specified schema
- **Authentication**: Built-in user authentication via AACU_F
- **Session Management**: APEX session security
- **API Key Protection**: Credentials stored in APEX Web Credentials

## 📊 Performance Optimization

- **Lazy Loading**: Charts render progressively
- **Query Caching**: Results cached with configurable TTL
- **Batch Processing**: Multiple widgets process in parallel
- **Schema Caching**: Database metadata cached for performance
- **Result Limiting**: Automatic row limits for preview data

## 🐛 Error Handling

The system includes comprehensive error handling:
- **AI Fallbacks**: Default layouts when AI fails
- **SQL Validation**: Pre-execution query validation
- **Graceful Degradation**: Partial dashboard rendering on widget failures
- **User Feedback**: Clear error messages and recovery suggestions

## 📈 Monitoring

Track system usage through:
- `SMART_QUERY` table for query history
- Dashboard creation metrics
- AI token usage (via OpenAI dashboard)
- APEX application logs

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Oracle APEX team for the powerful platform
- OpenAI for GPT models
- ApexCharts for visualization library
- Leaflet.js for map functionality

## 📧 Contact

For questions or support, please open an issue in the GitHub repository.

---

**Note**: This is an enterprise-grade solution designed for production use. Ensure proper testing in development environment before deployment.

## 🔄 Version History

- **v1.0.0** - Initial release with core dashboard generation
- **v1.1.0** - Added map visualizations and geographic analysis
- **v1.2.0** - Enhanced AI reasoning with GPT-5 support
- **v1.3.0** - Multi-language support and improved error handling

## 🚦 System Requirements

| Component | Minimum Version | Recommended Version |
|-----------|----------------|-------------------|
| Oracle Database | 19c | 21c or higher |
| Oracle APEX | 21.1 | 23.1 or higher |
| Browser | Chrome 90+ | Latest version |
| Screen Resolution | 1366x768 | 1920x1080 or higher |

## 💡 Tips & Best Practices

1. **Question Formulation**
   - Be specific about metrics and timeframes
   - Include relevant business context
   - Specify comparison criteria when needed

2. **Performance**
   - Index frequently queried columns
   - Optimize base tables and views
   - Use materialized views for complex aggregations

3. **AI Optimization**
   - Keep schema descriptions concise
   - Use meaningful table and column names
   - Add comments to complex database objects

---

*Built with ❤️ using Oracle APEX and AI*
