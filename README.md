# ha-cicd-worker

## Overview

Automated deployment of TapData via CI/CD. This repository serves as the shared deployment engine for multi-tenant environments, orchestrating automated deployment pipelines across multiple tenant repositories.

## Getting Started

- [Multi-Repo Multi-Tenant: Setup Checklist](docs/setup-checklist.md)

## Directory Structure

```
ha-cicd-worker/
├── .github/
│   └── workflows/                          # GitHub Actions workflow definitions
│       ├── tapdata-deploy.yml              # TapData deployment workflow (reusable)
│       └── tapdata-rollback.yml            # TapData rollback workflow (reusable)
├── conf/                                   # Configuration files
│   └── Task_Run_Order.json                 # Task DAG execution order
├── scripts/                                # Automation scripts
│   ├── common/                             # Shared utility scripts
│   │   ├── compress-files.sh               # Compress export files
│   │   ├── consolidate-previews.sh         # Merge dry-run preview results
│   │   ├── get-token.sh                    # Retrieve TapData access token
│   │   ├── import-resource.sh              # Import resources via TapData API
│   │   ├── preview-resource.sh             # Dry-run preview (no changes applied)
│   │   └── stop-tasks.sh                   # Stop running tasks
│   ├── tapdata-deploy/                     # Deployment-specific scripts
│   │   ├── detect-project.sh               # Detect project from export files
│   │   ├── generate-report.sh              # Generate deployment summary report
│   │   ├── generate-vault.sh               # Build secrets config from GitHub Secrets
│   │   └── validate-inputs.sh              # Validate workflow input parameters
│   ├── tapdata-rollback/                   # Rollback-specific scripts
│   │   ├── clean-resources.sh              # Clean existing resources before reimport
│   │   ├── resolve-tag.sh                  # Resolve rollback target tag
│   │   ├── start-and-publish.sh            # Start tasks and publish APIs
│   │   ├── unpublish-apis.sh               # Unpublish API endpoints
│   │   └── validate-inputs.sh              # Validate rollback input parameters
│   └── tapdata-rebuild/                    # Rebuild-specific scripts
│       ├── list-rebuild-tasks.sh           # List tasks to rebuild
│       ├── reset-tasks.sh                  # Reset task state
│       ├── run-tasks.sh                    # Execute tasks in DAG order
│       └── validate-inputs.sh              # Validate rebuild input parameters
├── tenant-template/                        # Template for new tenant repositories
│   └── .github/
│       └── workflows/
│           ├── tapdata-deploy.yml          # Caller workflow template (deploy)
│           └── tapdata-rollback.yml        # Caller workflow template (rollback)
├── docs/                                   # Documentation
│   └── setup-checklist.md                 # Pre-go-live setup checklist
└── README.md                              # This document
```
