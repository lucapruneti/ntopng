--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   alert_id = flow_alert_keys.flow_alert_iec_unexpected_type_id,

   -- Specify the default value when clicking on the "Reset Default" button
   default_value = {
      severity = alert_severities.warning,
      items = {
	 9,13,36,45,46,48,30,103,100,37
      },
   },

   gui = {
      i18n_title        = "flow_callbacks.iec104_unexpected_type_id_title",
      i18n_description  = "flow_callbacks.iec104_unexpected_type_id_description",
      input_builder     = "items_list", -- TODO: fix the input list
      input_title       = "flow_callbacks.iec104_unexpected_type_id_allowed_type_ids_title",
      input_description = "flow_callbacks.iec104_unexpected_type_id_allowed_type_ids_description",
   }
}

-- #################################################################

return script
