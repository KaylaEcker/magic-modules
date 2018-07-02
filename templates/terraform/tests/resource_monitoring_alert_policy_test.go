package google

import (
	"fmt"
	"github.com/hashicorp/terraform/helper/acctest"
	"github.com/hashicorp/terraform/helper/resource"
	"github.com/hashicorp/terraform/terraform"
	"testing"
)

func TestAccMonitoringAlertPolicy_basic(t *testing.T) {
	t.Parallel()

	name := acctest.RandomWithPrefix("tf-test")

	resource.Test(t, resource.TestCase{
		PreCheck:     func() { testAccPreCheck(t) },
		Providers:    testAccProviders,
		CheckDestroy: testAccCheckMonitoringAlertPolicyDestroy,
		Steps: []resource.TestStep{
			resource.TestStep{
				Config: testAccMonitoringAlertPolicy_basic(name),
			},
			resource.TestStep{
				ResourceName:      "google_monitoring_alert_policy.test",
				ImportState:       true,
				ImportStateVerify: true,
			},
		},
	})
}

func testAccCheckMonitoringAlertPolicyDestroy(s *terraform.State) error {
	// config := testAccProvider.Meta().(*Config)

	for _, rs := range s.RootModule().Resources {
		if rs.Type != "google_monitoring_alert_policy" {
			continue
		}

	}

	return nil
}

func testAccMonitoringAlertPolicy_basic(name string) string {
	return fmt.Sprintf(`
resource "google_monitoring_alert_policy" "test" {
  display_name = "%s"
  conditions{
    display_name = "%s"
    condition_threshold{
      filter = "project = \"trialanderror749\""
      duration = "60 seconds"
    }
  }
}`, name, name)
}
