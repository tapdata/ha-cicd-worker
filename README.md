# ha-cicd-worker

## Overview

Automated deployment of Tapdata via CI/CD. This repository serves as the execution hub for CI/CD workflows, responsible for orchestrating and running the automated deployment pipeline.

## Getting Started

- [Single-Repo Multi-Tenant Setup Guide](docs/setup-single-repo.md)
- [Multi-Repo Multi-Tenant Setup Guide](docs/setup-multi-repo.md)

## Directory Structure

```
ha-cicd-worker/
├── .github/
│   └── workflows/                    # GitHub Actions workflow definitions
│       ├── tapdata-deploy.yml        # Tapdata deployment workflow
│       └── tapdata-rollback.yml      # Tapdata rollback workflow
├── conf/                             # Configuration files
│   ├── env.conf                      # Environment configuration
│   └── project.conf                  # Project grouping configuration
├── scripts/                          # Automation scripts
│   └── tapdata-deploy/              # Deployment-related scripts
│       ├── compress-files.sh         # File compression
│       ├── generate-report.sh        # Generate deployment report
│       ├── generate-vault.sh         # Generate secrets configuration
│       ├── get-last-stable-tag.sh    # Get the latest stable tag
│       ├── get-token.sh              # Retrieve access token
│       ├── import-resource.sh        # Import resources
│       └── validate-inputs.sh        # Validate input parameters
├── requirements.txt                  # Python dependencies
└── README.md                        # This document
```