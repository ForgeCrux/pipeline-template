package main

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Context holds the global state, similar to GitHub Actions env and steps context.
type Context struct {
	Env     map[string]string
	Outputs map[string]map[string]string // stepID -> key -> value
	JobStatus string
}

func NewContext() *Context {
	return &Context{
		Env:     make(map[string]string),
		Outputs: make(map[string]map[string]string),
	}
}

// SetEnv sets environment variables for the child processes.
func (c *Context) SetEnv(key, value string) {
	c.Env[key] = value
}

// GetEnv retrieves an environment variable.
func (c *Context) GetEnv(key string) string {
	if val, ok := c.Env[key]; ok {
		return val
	}
	return os.Getenv(key)
}

// GetOutput retrieves a step output: steps.<stepID>.outputs.<key>
func (c *Context) GetOutput(stepID, key string) string {
	if stepOut, ok := c.Outputs[stepID]; ok {
		return stepOut[key]
	}
	return ""
}

// Step represents a single workflow step.
type Step struct {
	ID       string
	Name     string
	Run      string            // The bash script to execute
	Env      map[string]string // Step-specific env vars
	SoftFail bool              // If true, failures are treated as warnings (fixes issue 2)
}

// Stage represents a logical grouping of steps (fixes issue 3).
type Stage struct {
	Name  string
	Steps []Step
}

func main() {
	ctx := NewContext()
	ctx.SetEnv("GITHUB_WORKSPACE", "/home/runner/work/app-rtl-cps-saga-orchestrator-px/app-rtl-cps-saga-orchestrator-px")
	
	// Paths (matching the workflow)
	scriptsDir := filepath.Join(ctx.GetEnv("GITHUB_WORKSPACE"), "pipeline-template/scripts/apigee")
	ctx.SetEnv("ROOT_TEMPLATE_SCRIPTS", "pipeline-template/scripts")
	ctx.SetEnv("APIGEE_TEMPLATE_SCRIPTS", "pipeline-template/scripts/apigee")

	// --- Global Env Config (matching YAML) ---
	ctx.SetEnv("RESOURCE_TYPE", "apis")
	ctx.SetEnv("BUNDLE_DIR", "apiproxy")
	ctx.SetEnv("PIPELINE_LOGS_URL", "https://forgesphere.probestack.io/pipeline-logs")
	ctx.SetEnv("PL_PIPELINE_TYPE", "APIGEE")
	ctx.SetEnv("FLOW_TYPE", "apis")
	ctx.SetEnv("RESOURCE_ID", "saga-orchestrator")
	ctx.SetEnv("APIGEE_ORG", "gen-ai-poc-onboarding")
	ctx.SetEnv("APIGEE_ENV", "dev")
	ctx.SetEnv("DEPLOY_PROXY", "saga-orchestrator")
	ctx.SetEnv("BRANCH_NAME", "feature-adarsha")
	ctx.SetEnv("CICD_CONFIG_URL", "https://forgesphere.probestack.io/cicd-automation")
	
	// Simulating secrets
	ctx.SetEnv("PROB_SERVICE_TOKEN_URL", "https://mock.token.url")
	ctx.SetEnv("PROB_SERVICE_TOKEN_CLIENT_ID", "mock-client-id")
	ctx.SetEnv("PROB_SERVICE_TOKEN_CLIENT_SECRET", "mock-secret")
	ctx.SetEnv("PROB_SERVICE_TOKEN_TENANT_ID", "mock-tenant")
	ctx.SetEnv("TOKEN_ISSUER_URL", "https://mock.token.url")
	ctx.SetEnv("CLIENT_ID", "mock-client-id")
	ctx.SetEnv("CLIENT_SECRET", "mock-secret")
	ctx.SetEnv("ORGANIZATION_ID", "mock-tenant")
	ctx.SetEnv("CICD_CONFIG_ID", "6a5c4e4f19924f68338400de")

	// --- Define Pipeline Stages ---
	pipeline := []Stage{
		{
			Name: "SETUP",
			Steps: []Step{
				{ID: "setup", Name: "Setup stage", Run: fmt.Sprintf("bash %s/stages/setup.sh", scriptsDir)},
			},
		},
		{
			Name: "VALIDATION",
			Steps: []Step{
				{ID: "validation", Name: "Validation stage", Run: fmt.Sprintf("bash %s/stages/validation.sh", scriptsDir)},
			},
		},
		{
			Name: "FORGESPHERE_CONFIGURATION",
			Steps: []Step{
				{
					ID:   "config",
					Name: "ForgeSphere configuration stage",
					Run:  fmt.Sprintf("bash %s/stages/forgesphere_config.sh", scriptsDir),
					Env: map[string]string{
						"RESOURCE_TYPE": "apis",
						"ENVIRONMENT":   "dev", // Overrides APIGEE_ENV in script (fixes issue 5)
					},
				},
			},
		},
		{
			Name: "LINT",
			Steps: []Step{
				{
					ID:   "lint",
					Name: "Lint stage",
					Run:  fmt.Sprintf("bash %s/stages/lint.sh", scriptsDir),
					Env: map[string]string{
						"GH_LINT_TOKEN": "mock-app-token", // Fixes issue 4
					},
					SoftFail: true, // Fixes issue 2
				},
			},
		},
		{
			Name: "SONAR",
			Steps: []Step{
				{
					ID:   "sonar",
					Name: "Sonar stage",
					Run:  fmt.Sprintf("bash %s/stages/sonar.sh", scriptsDir),
					Env: map[string]string{
						"SONAR_HOST_URL":    "https://sonarcloud.io",
						"SONAR_TOKEN":       "mock-sonar-token",
						"SONAR_PROJECT_KEY": "saga-orchestrator",
					},
					SoftFail: true, // Fixes issue 2
				},
			},
		},
		{
			Name: "VERSION",
			Steps: []Step{
				{ID: "version", Name: "Calculate version", Run: fmt.Sprintf("bash %s/stages/version.sh", scriptsDir)},
			},
		},
		{
			Name: "PACKAGE",
			Steps: []Step{
				{ID: "package", Name: "Package stage", Run: fmt.Sprintf("bash %s/stages/package.sh", scriptsDir)},
			},
		},
		{
			Name: "NEXUS",
			Steps: []Step{
				{
					ID:   "nexus",
					Name: "Nexus stage",
					Run:  fmt.Sprintf("bash %s/stages/nexus.sh", scriptsDir),
					// Nexus is not skipped here. Script handles it (fixes issue 1)
				},
			},
		},
		{
			Name: "GCP_AUTH",
			Steps: []Step{
				{ID: "gcp-auth", Name: "GCP auth stage", Run: fmt.Sprintf("bash %s/stages/gcp_auth.sh", scriptsDir)},
			},
		},
		{
			Name: "IMPORT",
			Steps: []Step{
				{ID: "import", Name: "Import stage", Run: fmt.Sprintf("bash %s/stages/import.sh", scriptsDir)},
			},
		},
		{
			Name: "REVISION",
			Steps: []Step{
				{ID: "revision", Name: "Revision stage", Run: fmt.Sprintf("bash %s/stages/revision.sh", scriptsDir)},
			},
		},
		{
			Name: "DEPLOYMENT",
			Steps: []Step{
				{ID: "deploy", Name: "Deploy stage", Run: fmt.Sprintf("bash %s/stages/deploy.sh", scriptsDir)},
			},
		},
		{
			Name: "VERIFY",
			Steps: []Step{
				{ID: "verify", Name: "Verify stage", Run: fmt.Sprintf("bash %s/stages/verify.sh", scriptsDir)},
			},
		},
		{
			Name: "CLEANUP",
			Steps: []Step{
				{ID: "cleanup", Name: "Cleanup", Run: fmt.Sprintf("bash %s/stages/cleanup.sh", scriptsDir)},
			},
		},
	}

	// --- Execute Pipeline ---
	runner := &Runner{ctx: ctx}
	err := runner.RunPipeline(pipeline)
	if err != nil {
		ctx.JobStatus = "failure"
		fmt.Printf("Pipeline failed: %v\n", err)
		os.Exit(1)
	}
	
	ctx.JobStatus = "success"
	fmt.Println("Pipeline completed successfully.")
}

type Runner struct {
	ctx *Context
}

func (r *Runner) RunPipeline(pipeline []Stage) error {
	for _, stage := range pipeline {
		err := r.RunStage(stage)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *Runner) RunStage(stage Stage) error {
	fmt.Printf("\n::group::%s\n", stage.Name)
	// Simulate STAGE_STARTED
	r.emitEvent(stage.Name, "STAGE_STARTED", "RUNNING", "Stage started")

	stageFailed := false
	var warnings []string

	for _, step := range stage.Steps {
		err := r.RunStep(stage.Name, step)
		if err != nil {
			if step.SoftFail {
				// Fixes issue 2: Soft fail
				warnings = append(warnings, fmt.Sprintf("WARNING: %s failed but ignored", step.Name))
				fmt.Printf("::warning::%s failed, continuing...\n", step.Name)
			} else {
				stageFailed = true
				break
			}
		}
	}

	// Fixes issue 3: Stage status is emitted only at the end
	if stageFailed {
		r.emitEvent(stage.Name, "STAGE_COMPLETED", "FAILED", "Stage failed")
		fmt.Printf("::endgroup::\n")
		return fmt.Errorf("stage %s failed", stage.Name)
	}

	msg := "Stage completed"
	if len(warnings) > 0 {
		msg = fmt.Sprintf("WARNING: Stage completed with warnings: %s", strings.Join(warnings, "; "))
	}
	r.emitEvent(stage.Name, "STAGE_COMPLETED", "COMPLETED", msg)
	fmt.Printf("::endgroup::\n")
	return nil
}

func (r *Runner) RunStep(stageName string, step Step) error {
	fmt.Printf("Running step: %s\n", step.Name)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	// Create a temp file to capture outputs
	outputFile := filepath.Join(os.TempDir(), fmt.Sprintf("output-%d", time.Now().UnixNano()))
	os.WriteFile(outputFile, []byte{}, 0644)
	defer os.Remove(outputFile)

	cmd := exec.CommandContext(ctx, "bash", "-c", step.Run)
	
	// Set environment
	cmd.Env = os.Environ()
	for k, v := range r.ctx.Env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}
	for k, v := range step.Env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
	}
	// Fixes GitHub Actions $GITHUB_OUTPUT mechanism
	cmd.Env = append(cmd.Env, fmt.Sprintf("GITHUB_OUTPUT=%s", outputFile))
	cmd.Env = append(cmd.Env, fmt.Sprintf("GITHUB_ENV=%s", outputFile)) // Simplified: same file for both

	// Stream stdout/stderr
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	
	// Parse outputs written by the shell script
	r.parseOutputs(step.ID, outputFile)

	if err != nil {
		fmt.Printf("Step %s failed: %v\n", step.Name, err)
		return err
	}
	return nil
}

// parseOutputs reads the $GITHUB_OUTPUT file and stores keys in context
func (r *Runner) parseOutputs(stepID, outputFile string) {
	file, err := os.Open(outputFile)
	if err != nil {
		return
	}
	defer file.Close()

	if _, ok := r.ctx.Outputs[stepID]; !ok {
		r.ctx.Outputs[stepID] = make(map[string]string)
	}

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		// Simple parsing of key=value
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			r.ctx.Outputs[stepID][parts[0]] = parts[1]
		}
	}
}

// emitEvent simulates the pipeline_logs.py event call
func (r *Runner) emitEvent(stage, step, status, message string) {
	// In a real scenario, this makes an HTTP POST to PIPELINE_LOGS_URL
	// We print it to stdout to mimic the behavior.
	fmt.Printf("[EVENT] Stage: %s | Step: %s | Status: %s | Message: %s\n", stage, step, status, message)
}