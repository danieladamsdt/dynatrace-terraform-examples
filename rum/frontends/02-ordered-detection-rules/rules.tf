# Detection rules are an ordered list, and the dynatrace provider orders them
# with `insert_after`. A new rule with no `insert_after` is appended to the end,
# so rules created in parallel land in a random order.
#
# Terraform cannot chain instances of one resource ("Self-referential block"),
# and `for_each`/`count` creation order is not controlled even with
# -parallelism=1. The only way to get a deterministic order is one resource
# block per rule, each pointing at the one before it. That is what the slots
# below do; a slot is created only if var.detection_rules has an entry for it.
#
# To support more than 5 rules, copy the last slot, bump its index, and point
# its insert_after at the slot above it.

resource "dynatrace_application_detection_rule_v2" "slot_1" {
  count = length(var.detection_rules) > 0 ? 1 : 0

  application_id = local.entity_id
  matcher        = var.detection_rules[0].matcher
  pattern        = var.detection_rules[0].pattern
  description    = var.detection_rules[0].description
  insert_after   = var.insert_after
}

resource "dynatrace_application_detection_rule_v2" "slot_2" {
  count = length(var.detection_rules) > 1 ? 1 : 0

  application_id = local.entity_id
  matcher        = var.detection_rules[1].matcher
  pattern        = var.detection_rules[1].pattern
  description    = var.detection_rules[1].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_1[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_3" {
  count = length(var.detection_rules) > 2 ? 1 : 0

  application_id = local.entity_id
  matcher        = var.detection_rules[2].matcher
  pattern        = var.detection_rules[2].pattern
  description    = var.detection_rules[2].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_2[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_4" {
  count = length(var.detection_rules) > 3 ? 1 : 0

  application_id = local.entity_id
  matcher        = var.detection_rules[3].matcher
  pattern        = var.detection_rules[3].pattern
  description    = var.detection_rules[3].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_3[*].id)
}

resource "dynatrace_application_detection_rule_v2" "slot_5" {
  count = length(var.detection_rules) > 4 ? 1 : 0

  application_id = local.entity_id
  matcher        = var.detection_rules[4].matcher
  pattern        = var.detection_rules[4].pattern
  description    = var.detection_rules[4].description
  insert_after   = one(dynatrace_application_detection_rule_v2.slot_4[*].id)
}
