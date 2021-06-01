/*
 *
 * (C) 2013-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _SCORE_ANOMALY_H_
#define _SCORE_ANOMALY_H_

#include "ntop_includes.h"

class ScoreAnomaly : public HostCallback {
private:
  
public:
  ScoreAnomaly();
  ~ScoreAnomaly() {};

  ScoreAnomalyAlert *allocAlert(HostCallback *c, Host *h, u_int8_t cli_score, u_int8_t srv_score, bool is_both, bool is_client_alert, u_int32_t _value, u_int32_t _lower_bound, u_int32_t _upper_bound) {
    ScoreAnomalyAlert *alert = new ScoreAnomalyAlert(c, h, cli_score, srv_score, is_both, is_client_alert, _value, _lower_bound, _upper_bound);

    if(is_client_alert)
      alert->setAttacker();
    else
      alert->setVictim();

    return alert;
  };

  bool loadConfiguration(json_object *config);
  void periodicUpdate(Host *h, HostAlert *engaged_alert);
  
  HostCallbackID getID() const { return host_callback_score_anomaly; }
  std::string getName()  const { return(std::string("score_anomaly")); }
};

#endif
