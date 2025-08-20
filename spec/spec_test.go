package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("Logsearch Kit", func() {

	Describe("Base Deployment", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "base-all-params",
			CloudConfig: "aws", 
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "azure",
			CloudConfig: "azure",
			CPI:         "azure",
		})
		
		Test(Environment{
			Name:        "gcp",
			CloudConfig: "gcp",
			CPI:         "gcp",
		})
	})

	Describe("Feature Combinations", func() {
		Test(Environment{
			Name:        "small-footprint",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "s3-blobstore",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "azure-blobstore",
			CloudConfig: "azure",
			CPI:         "azure",
		})
		
		Test(Environment{
			Name:        "gcs-blobstore",
			CloudConfig: "gcp",
			CPI:         "gcp",
		})
		
		Test(Environment{
			Name:        "prometheus-monitoring",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "cf-integration",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "external-elasticsearch",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("Complex Scenarios", func() {
		Test(Environment{
			Name:        "production-s3",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "production-azure",
			CloudConfig: "azure",
			CPI:         "azure",
		})
		
		Test(Environment{
			Name:        "monitoring-alerting",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "cf-monitoring",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("Addon Features", func() {
		Test(Environment{
			Name:        "custom-parsers",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "enhanced-curator",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		
		Test(Environment{
			Name:        "alerting",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})
})