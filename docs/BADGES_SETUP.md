# Dynamic Badges Setup Guide

This guide explains how to set up dynamic quality metric badges for your README using GitHub Gists and Shields.io.

## Prerequisites

- GitHub account with access to create Gists
- Repository with quality gates configured

## Setup Steps

### 1. Create a GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "Quality Badges - NixOS Config"
4. Select scope: `gist` (create gists)
5. Click "Generate token"
6. **Copy the token** - you won't see it again!

### 2. Add Token to Repository Secrets

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `GIST_SECRET`
4. Value: Paste your personal access token
5. Click "Add secret"

### 3. Create a Public Gist

1. Go to https://gist.github.com/
2. Create a new gist:
   - Description: "NixOS Config Quality Badges"
   - Filename: `coverage.json`
   - Content:
     ```json
     {
       "schemaVersion": 1,
       "label": "coverage",
       "message": "N/A",
       "color": "inactive"
     }
     ```
3. Create as **Public** gist
4. Note the Gist ID from the URL: `https://gist.github.com/USERNAME/GIST_ID`

### 4. Update Quality Gates Workflow

The `.github/workflows/quality-gates.yml` needs to be updated to push badge data to your gist.

Add this step after the "Upload Metrics Artifact" step:

```yaml
      - name: "Update Dynamic Badges"
        if: github.ref == 'refs/heads/main'
        uses: Schneegans/dynamic-badges-action@v1.7.0
        with:
          auth: ${{ secrets.GIST_SECRET }}
          gistID: YOUR_GIST_ID_HERE  # Replace with your gist ID

          # Coverage badge
          filename: coverage.json
          label: Coverage
          message: ${{ env.COVERAGE_PERCENT }}%
          color: ${{ env.COVERAGE_PERCENT >= 80 && 'brightgreen' || (env.COVERAGE_PERCENT >= 60 && 'yellow' || 'red') }}

      - name: "Update Performance Badge"
        if: github.ref == 'refs/heads/main'
        uses: Schneegans/dynamic-badges-action@v1.7.0
        with:
          auth: ${{ secrets.GIST_SECRET }}
          gistID: YOUR_GIST_ID_HERE  # Same gist ID

          # Performance badge
          filename: eval-time.json
          label: Eval Time
          message: ${{ env.EVAL_TIME }}s
          color: ${{ env.EVAL_TIME < 10 && 'brightgreen' || (env.EVAL_TIME < 15 && 'yellow' || 'red') }}

      - name: "Update Quality Gates Badge"
        if: github.ref == 'refs/heads/main'
        uses: Schneegans/dynamic-badges-action@v1.7.0
        with:
          auth: ${{ secrets.GIST_SECRET }}
          gistID: YOUR_GIST_ID_HERE  # Same gist ID

          # Quality gates badge
          filename: quality-gates.json
          label: Quality Gates
          message: ${{ steps.dead-code.outputs.dead_code_status == 'passed' && steps.unused-modules.outputs.unused_modules_status == 'passed' && steps.coverage.outputs.coverage_status == 'passed' && steps.performance.outputs.performance_status == 'passed' && 'passing' || 'failing' }}
          color: ${{ steps.dead-code.outputs.dead_code_status == 'passed' && steps.unused-modules.outputs.unused_modules_status == 'passed' && steps.coverage.outputs.coverage_status == 'passed' && steps.performance.outputs.performance_status == 'passed' && 'brightgreen' || 'red' }}
```

### 5. Add Badges to README

After the first successful run, add these badges to your `README.md`:

```markdown
# NixOS Configuration

![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/USERNAME/GIST_ID/raw/coverage.json)
![Eval Time](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/USERNAME/GIST_ID/raw/eval-time.json)
![Quality Gates](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/USERNAME/GIST_ID/raw/quality-gates.json)
![CI](https://github.com/USERNAME/REPO/workflows/CI%20Pipeline/badge.svg)
```

Replace:
- `USERNAME` with your GitHub username
- `GIST_ID` with your gist ID
- `REPO` with your repository name

## Badge Customization

### Colors

Badges use these color thresholds by default:
- **Coverage**: Green (≥80%), Yellow (60-79%), Red (<60%)
- **Eval Time**: Green (<10s), Yellow (10-15s), Red (>15s)
- **Quality Gates**: Green (all passing), Red (any failing)

### Custom Metrics

You can create additional badges for any metric by:
1. Extracting the metric in the quality-gates workflow
2. Creating a new badge update step
3. Adding the badge URL to your README

Example for closure size:

```yaml
- name: "Update Closure Size Badge"
  uses: Schneegans/dynamic-badges-action@v1.7.0
  with:
    auth: ${{ secrets.GIST_SECRET }}
    gistID: YOUR_GIST_ID
    filename: closure-size.json
    label: Closure Size
    message: ${{ env.CLOSURE_SIZE }}MB
    color: ${{ env.CLOSURE_SIZE < 3000 && 'brightgreen' || 'orange' }}
```

## Troubleshooting

### Badges show "invalid"
- Check that the gist ID is correct in the workflow
- Verify the gist is public
- Ensure the GIST_SECRET token has `gist` scope

### Badges don't update
- Check that the workflow runs successfully on main branch
- Verify the token hasn't expired
- Check workflow logs for badge update step errors

### Badge shows old data
- Shields.io caches badge images for ~5 minutes
- Add `?nocache=1` to the badge URL to bypass cache during testing

## Example

See the live example at: `https://USERNAME.github.io/REPO/`

## Additional Resources

- [Shields.io Endpoint Documentation](https://shields.io/badges/endpoint-badge)
- [dynamic-badges-action](https://github.com/Schneegans/dynamic-badges-action)
- [GitHub Gist API](https://docs.github.com/en/rest/gists)
