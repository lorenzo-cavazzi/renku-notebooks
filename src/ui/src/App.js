import React, { Component } from 'react';
import './App.css';
import Notebooks from './notebooks';

class App extends Component {
  render() {
    const servicePrefix = "../"
    return (
      <div className="container-fluid">
        <Notebooks.Admin statusUrl={servicePrefix} stopServerUrl={`${servicePrefix}stop/`} />
      </div>
    );
  }
}

export default App;
