import * as React from "react";
import * as ReactDOM from "react-dom";
import Routing from "./Routing";

function App() {
  return (
    <div>
      <Routing />
    </div>
  );
}

ReactDOM.render(
    <App />,
    document.getElementById("monitor-app")
);
