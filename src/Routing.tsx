
import React, { useContext } from "react";
import { BrowserRouter as Router, Switch, Route } from "react-router-dom";

export default () => {
  return (
    <div className="monitor-routing">
      <Router>
        <Switch>
          <Route path="/">
          </Route>
        </Switch>
      </Router>
    </div>
  );
}
