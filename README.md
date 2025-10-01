# Azure DevOps to GitHub Migration Toolkit

A comprehensive PowerShell toolkit for migrating repositories from Azure DevOps (ADO) to GitHub using the GitHub CLI `ado2gh` extension.

## Overview

This toolkit provides a structured approach to migrate repositories from Azure DevOps to GitHub with comprehensive validation and reporting. It supports both single repository migrations and batch migrations with detailed logging and validation checks.

## Prerequisites

### Required Tools
- **PowerShell 5.1** or later
- **GitHub CLI (gh)** - [Installation guide](https://cli.github.com/)
- **ADO2GH GitHub CLI Extension**:
  ```powershell
  gh extension install github/gh-ado2gh
  ```

### Required Environment Variables
Set the following environment variables before running any scripts:

```powershell
# Azure DevOps Personal Access Token
$env:ADO_PAT = "your-ado-personal-access-token"

# GitHub Personal Access Token  
$env:GH_PAT = "your-github-personal-access-token"
```

### Token Permissions

**Azure DevOps PAT** requires:
- Code (Read)
- Project and Team (Read)
- Identity (Read)
- Work Items (Read)

**GitHub PAT** requires:
- `repo` (Full control of private repositories)
- `workflow` (Update GitHub Action workflows)
- `admin:org` (Full control of orgs and teams)

## Project Structure

```
PowerShell/
├── 0_generate_inventory.ps1    # Generate ADO inventory report
├── 1_pilot_migration.ps1       # Single repository pilot migration
├── 2_check_repo_lock.ps1       # Check repository lock status
├── 3_mannequin_generate.ps1    # Generate mannequin users
├── 4_mannequin_reclaim.ps1     # Reclaim mannequin users
├── 5_migration_validation.ps1  # Batch migration with validation
├── mannequins.csv              # Generated mannequin user data
├── orgs.csv                    # Organization inventory
├── pipelines.csv               # Pipeline inventory
├── repos.csv                   # Repository inventory
└── team-projects.csv           # Team project inventory
```

## Usage Guide

### Step 1: Generate Inventory Report

Start by generating a comprehensive inventory of your Azure DevOps organization:

```powershell
.\0_generate_inventory.ps1
```

**What it does:**
- Scans your ADO organization for repositories, team projects, pipelines
- Generates CSV files with detailed information
- Provides baseline data for migration planning

### Step 2: Pilot Migration (Recommended)

Test the migration process with a single repository:

```powershell
.\1_pilot_migration.ps1
```

**Configuration:**
Edit the script variables to match your environment:
```powershell
$ADO_ORG = "your-ado-org"
$ADO_TEAM_PROJECT = "your-team-project" 
$ADO_REPO = "your-repo-name"
$GITHUB_ORG = "your-github-org"
$GITHUB_REPO = "new-repo-name"
```

**What it does:**
- Locks the ADO repository (read-only)
- Migrates repository to GitHub
- Performs comprehensive validation
- Compares branches, commits, and commit history
- Generates detailed migration log

### Step 3: Check Repository Lock Status

Verify repository lock status before proceeding:

```powershell
.\2_check_repo_lock.ps1
```

### Step 4: Manage Mannequin Users

Generate mannequin users for contributors who don't have GitHub accounts:

```powershell
.\3_mannequin_generate.ps1
```

Reclaim mannequin users after migration:

```powershell
.\4_mannequin_reclaim.ps1
```

### Step 5: Batch Migration

Execute migration for multiple repositories:

```powershell
.\5_migration_validation.ps1
```

**What it does:**
- Reads repository list from `repos.csv`
- Migrates each repository sequentially
- Locks each ADO repository before migration
- Performs validation for each migrated repository
- Generates comprehensive migration logs
- Includes 30-second pause between migrations

## Migration Validation

The toolkit includes comprehensive validation that checks:

### Branch Validation
- ✅ Branch count comparison (ADO vs GitHub)
- ✅ Branch name matching
- ✅ Missing branches identification

### Commit Validation
- ✅ Commit count per branch
- ✅ Latest commit SHA verification
- ✅ Complete commit history integrity

### Repository Metadata
- ✅ Repository creation date
- ✅ Default branch configuration
- ✅ Repository visibility settings
- ✅ Repository size comparison

## Configuration

### Organization Settings
Update the following variables in each script:

```powershell
# Azure DevOps Configuration
$ADO_ORG = "your-ado-organization"

# GitHub Configuration  
$GITHUB_ORG = "your-github-organization"
```

### CSV File Format

The `repos.csv` file should contain:
```csv
org,teamproject,repo,url,last-push-date,pipeline-count,compressed-repo-size-in-bytes,most-active-contributor,pr-count,commits-past-year
```

## Logging and Output

### Log Files
- **Pilot Migration**: `pilot-migration-log-YYYYMMDD.txt`
- **Batch Migration**: `migration-log-YYYYMMDD.txt`
- **Validation Reports**: `validation-{repo-name}.json`

### Log Content
- Timestamped migration steps
- Validation results with ✅/❌ status indicators
- Branch and commit comparison details
- Error messages and troubleshooting information

## Best Practices

### Before Migration
1. ✅ **Test with pilot migration** - Always start with a single repository
2. ✅ **Backup critical repositories** - Ensure you have backups before migration
3. ✅ **Communicate with teams** - Notify development teams about the migration
4. ✅ **Plan migration windows** - Schedule migrations during low-activity periods

### During Migration
1. ✅ **Monitor logs actively** - Watch for errors and validation failures
2. ✅ **Verify validation results** - Check all validation steps pass
3. ✅ **Handle mannequin users** - Plan for user account mapping
4. ✅ **Test migrated repositories** - Verify functionality post-migration

### After Migration
1. ✅ **Update team workflows** - Redirect teams to new GitHub repositories
2. ✅ **Update CI/CD pipelines** - Reconfigure automated processes
3. ✅ **Archive ADO repositories** - Keep ADO repos for historical reference
4. ✅ **Document the process** - Record lessons learned and issues encountered

## Troubleshooting

### Common Issues

**Missing Environment Variables**
```
Error: Missing ADO_PAT Environment Variable
```
**Solution**: Set required environment variables before running scripts

**Migration Validation Failures**
```
❌ Not Matching - Branch Count: ADO=5 | GitHub=3
```
**Solution**: Check network connectivity and re-run migration

**Repository Lock Failures**
```
Error: Unable to lock repository
```
**Solution**: Verify ADO permissions and repository access

### Support Resources
- [GitHub CLI ADO2GH Extension Documentation](https://github.com/github/gh-ado2gh)
- [Azure DevOps REST API Documentation](https://docs.microsoft.com/en-us/rest/api/azure/devops/)
- [GitHub REST API Documentation](https://docs.github.com/en/rest)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with pilot migrations
5. Submit a pull request

## License

This project is provided as-is for educational and migration purposes. Please review and comply with your organization's policies regarding data migration and tool usage.

---

**Note**: This toolkit is designed for Azure DevOps to GitHub migrations using the official GitHub CLI extension. Always test thoroughly in a non-production environment before executing production migrations.