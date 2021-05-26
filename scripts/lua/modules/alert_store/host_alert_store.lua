--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local json = require "dkjson"

-- ##############################################

local host_alert_store = classes.class(alert_store)

-- ##############################################

function host_alert_store:init(args)
   self.super:init()

   self._table_name = "host_alerts"
   self._alert_entity = alert_entities.host
end

-- ##############################################

function host_alert_store:insert(alert)
   local is_attacker = ternary(alert.is_attacker, 1, 0)
   local is_victim = ternary(alert.is_victim, 1, 0)
   local ip = alert.ip
   local vlan_id = alert.vlan_id

   if not ip then -- Compatibility with Lua alerts
      local host_info = hostkey2hostinfo(alert.entity_val)
      ip = host_info.host
      vlan_id = host_info.vlan
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, ip, vlan_id, name, is_attacker, is_victim, tstamp, tstamp_end, severity, score, granularity, json) "..
      "VALUES (%u, '%s', %u, '%s', %u, %u, %u, %u, %u, %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      ip,
      vlan_id or 0,
      self:_escape(alert.name),
      is_attacker,
      is_victim,
      alert.tstamp,
      alert.tstamp_end,
      ntop.mapScoreToSeverity(alert.score),
      alert.score,
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters on host address
--@param ip The host IP
--@return True if set is successful, false otherwise
function host_alert_store:add_ip_filter(ip)
   if not self._ip then
      self._ip = ip
      self._where[#self._where + 1] = string.format("ip = '%s'", self._ip)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filters on VLAN ID
--@param ip The VLAN ID
--@return True if set is successful, false otherwise
function host_alert_store:add_vlan_id_filter(vlan_id)
   if not self._vlan_id and tonumber(vlan_id) then
      self._vlan_id = tonumber(vlan_id)
      self._where[#self._where + 1] = string.format("vlan_id = %u", self._vlan_id)
      return true
   end

   return false
end

-- ##############################################

--@brief Add filter on role
--@param role The role (attacker or victim)
--@return True if set is successful, false otherwise
function host_alert_store:add_role_filter(role)
   if not self._role then
      self._role = role
      if role == 'attacker' then
         self._where[#self._where + 1] = "is_attacker = 1"
      elseif role == 'victim' then
         self._where[#self._where + 1] = "is_victim = 1"
      end
      return true
   end

   return false
end


-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function host_alert_store:_add_additional_request_filters()
   local ip = _GET["ip"]
   local vlan_id = _GET["vlan_id"]
   local role = _GET["role"]

   if not isEmptyString(vlan_id) then
      local vlan_id, op = self:strip_filter_operator(vlan_id)
      self:add_vlan_id_filter(vlan_id)
   end

   if not isEmptyString(ip) then
      local ip, op = self:strip_filter_operator(ip)
      local host = hostkey2hostinfo(ip)
      self._entity_value = hostinfo2hostkey(host)

      if not isEmptyString(host["host"]) then
         self:add_ip_filter(host["host"])
      end
      if not isEmptyString(host["vlan"]) then
         self:add_vlan_id_filter(host["vlan"])
      end
   end

   if not isEmptyString(role) then
      local role, op = self:strip_filter_operator(role)
      self:add_role_filter(role)
   end
end

-- ##############################################

--@brief Get info about additional available filters
function host_alert_store:_get_additional_available_filters()
   local filters = {
      alert_id = {
         value_type = 'alert_id',
      }, 
      ip = {
         value_type = 'ip',
      },
      role = {
        value_type = 'role',
      },
   }

   return filters
end 

-- ##############################################

function host_alert_store:printMyTable(table)
   
   traceError(TRACE_ERROR, TRACE_CONSOLE, "#"..tostring(#table))
   if #table == 0 then
      return
   end

   for key, value in pairs(table) do
      if type(value)=="table" then
         -- traceError(TRACE_ERROR, TRACE_CONSOLE, "KEY = "..key.." VALUE "..value.value)
         self:printMyTable(value)
      else
         traceError(TRACE_ERROR, TRACE_CONSOLE, "KEY = "..key.." VALUE "..value)      
      end
   end
end

function host_alert_store:format_txt_record(value)
   local tmp_json_record = self:format_json_record(value, true)
   -- self:printMyTable(tmp_json_record)
   return tmp_json_record
end

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function host_alert_store:format_json_record(value, no_html)
   local href_icon = "<i class='fas fa-laptop'></i>"
   local record = self:format_json_record_common(value, alert_entities.host.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.host.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)
   local host = hostinfo2hostkey(value)
   local reference_html = nil

   reference_html = hostinfo2detailshref({ip = value["ip"], vlan = value["vlan_id"]}, nil, href_icon, "", true)
   if reference_html == href_icon then
      reference_html = nil
   end

   record["ip"] = {
      value = host,
      label = host,
      shown_label = host,
      reference = reference_html 
   }

   -- Checking that the name of the host is not empty
   if value["name"] and (not isEmptyString(value["name"])) then
      record["ip"]["label"] = value["name"]
   end

   record["ip"]["shown_label"] = record["ip"]["label"]
   record["is_victim"] = ""
   record["is_attacker"] = ""

   if value["is_victim"] == true or value["is_victim"] == "1" then
      if no_html then
         record["is_victim"] = tostring(true)
      else
         record["is_victim"] = '<span style="color: #008000;">✓</span>'
         record["role"] = {
            label = i18n("victim"),
            value = "victim",
          }
      end
   elseif no_html then
      record["is_victim"] = tostring(false)
   end

   if value["is_attacker"] == true or value["is_attacker"] == "1" then
      if no_html then
         record["is_attacker"] = tostring(true)
      else
         record["is_attacker"] = '<span style="color: #008000;">✓</span>'
         record["role"] = {
           label = i18n("attacker"),
           value = "attacker",
         }
      end
   elseif no_html then
      record["is_attacker"] = tostring(false) 
   end

   record["vlan_id"] = value["vlan_id"] or 0

   record["alert_name"] = alert_name

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   record["msg"] = {
     name = noHtml(alert_name),
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info, value)
   }

   return record
end

-- ##############################################

return host_alert_store
