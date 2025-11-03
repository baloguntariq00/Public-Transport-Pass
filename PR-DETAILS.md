Group Pass Management System

Overview
A comprehensive group pass management system that enables families, organizations, and teams to create shared transport passes with pooled balances, member management, and collaborative ride sharing. This independent feature extends the Public Transport Pass contract without modifying existing functionality.

Technical Implementation
**New Data Structures:**
- `group-passes`: Maps group IDs to group metadata (admin, name, description, member limits, shared balance)
- `group-members`: Maps group-member pairs to membership details (join date, ride count, contributions)
- `user-groups`: Maps users to their group memberships (max 5 groups per user)

**Key Functions Added:**
- `create-group-pass`: Create new group with initial balance and member limit
- `join-group`: Join existing group with contribution requirement
- `contribute-to-group`: Add funds to group's shared balance
- `use-group-balance-for-ride`: Deduct ride costs from group balance
- `remove-group-member`: Admin function to remove members
- `deactivate-group`: Admin function to disable group

**Read-Only Functions:**
- `get-group-info`: Retrieve complete group information
- `get-group-member-info`: Get member-specific details
- `get-user-groups`: List user's group memberships
- `is-user-group-member`/`is-user-group-admin`: Membership verification

Testing & Validation
- ✅ Contract passes clarinet check
- ✅ All npm tests successful  
- ✅ CI/CD pipeline configured
- ✅ Clarity v3 compliant with proper error handling
- ✅ Independent implementation with no cross-contract dependencies
- ✅ Comprehensive error constants for group management scenarios