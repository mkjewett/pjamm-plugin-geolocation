declare module '@capacitor/core' {
  interface PluginRegistry {
    PJAMMGeolocation: PJAMMGeolocationPlugin;
  }
}

export interface PJAMMGeolocationPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
