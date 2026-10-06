# Detection rules, in bundle order (highest precedence first).
#
# The dynatrace provider orders rules with `insert_after`, and Terraform cannot
# chain instances of one resource, so a deterministic order needs one resource
# block per rule. A slot is created only if the bundle has a rule for it. See
# ../../frontends-classic/02-detection-rules for the reasoning.
#
# To support more than 10 rules, copy the last slot, bump its index, and point
# its insert_after at the slot above it.

resource "dynatrace_application_detection_rule_v2" "slot_1" {
  count = length(local.rules) > 0 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[0].matcher
  pattern        = local.rules[0].pattern
  description    = local.rules[0].description
  insert_after   = var.insert_rules_after
}

resource "dynatrace_application_detection_rule_v2" "slot_2" {
  count = length(local.rules) > 1 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[1].matcher
  pattern        = local.rules[1].pattern
  description    = local.rules[1].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_1[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_3" {
  count = length(local.rules) > 2 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[2].matcher
  pattern        = local.rules[2].pattern
  description    = local.rules[2].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_2[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_4" {
  count = length(local.rules) > 3 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[3].matcher
  pattern        = local.rules[3].pattern
  description    = local.rules[3].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_3[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_5" {
  count = length(local.rules) > 4 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[4].matcher
  pattern        = local.rules[4].pattern
  description    = local.rules[4].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_4[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_6" {
  count = length(local.rules) > 5 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[5].matcher
  pattern        = local.rules[5].pattern
  description    = local.rules[5].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_5[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_7" {
  count = length(local.rules) > 6 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[6].matcher
  pattern        = local.rules[6].pattern
  description    = local.rules[6].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_6[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_8" {
  count = length(local.rules) > 7 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[7].matcher
  pattern        = local.rules[7].pattern
  description    = local.rules[7].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_7[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_9" {
  count = length(local.rules) > 8 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[8].matcher
  pattern        = local.rules[8].pattern
  description    = local.rules[8].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_8[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_10" {
  count = length(local.rules) > 9 ? 1 : 0

  application_id = local.entity_id
  matcher        = local.rules[9].matcher
  pattern        = local.rules[9].pattern
  description    = local.rules[9].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_9[*].id)
}

check "rule_slots" {
  assert {
    condition     = length(local.rules) <= 10
    error_message = "The bundle has ${length(local.rules)} detection rules but rules.tf only has 10 slots; the extra rules were not imported. Add slots."
  }
}
