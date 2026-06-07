# Advanced Native Patterns

Reference for robust native code: authoring a custom plugin bridge, and the typed error-handling wrapper. Read when writing a native plugin not available as an npm package, or hardening native calls.

## Custom Plugin Bridge Pattern

For native plugins not available as npm packages, follow this 4-layer pattern:

1. **Swift plugin** (`ios/App/App/YourPlugin.swift`):

   ```swift
   import Capacitor
   @objc(YourPlugin)
   public class YourPlugin: CAPPlugin, CAPBridgedPlugin {
       public let identifier = "YourPlugin"
       public let jsName = "YourPlugin"
       public let pluginMethods: [CAPPluginMethod] = []
       func handleEvent(_ data: SomeType) {
           notifyListeners("eventName", data: ["key": data.value])
       }
   }
   ```

2. **ObjC registration** (`ios/App/App/YourPlugin.m`):

   ```objc
   #import <Capacitor/Capacitor.h>
   CAP_PLUGIN(YourPlugin, "YourPlugin",)
   ```

3. **TypeScript interface** — `registerPlugin()` returns `unknown` without a type parameter:

   ```typescript
   import { registerPlugin, type Plugin } from '@capacitor/core';
   interface YourPlugin extends Plugin {
     addListener(
       eventName: 'eventName',
       fn: (data: { key: string }) => void
     ): Promise<{ remove: () => Promise<void> }>;
   }
   const YourPlugin = registerPlugin<YourPlugin>('YourPlugin');
   ```

4. **React hook** — register listener inside `useEffect` with `isNativePlatform()` guard and cleanup via `handle.remove()`

## Error Handling — typed wrapper

A reusable typed error + `safeNativeCall` wrapper so every native call has consistent availability gating, fallback, and error context.

```typescript
class CapacitorError extends Error {
  constructor(
    message: string,
    public readonly plugin: string,
    public readonly platform: string
  ) {
    super(`[${plugin}@${platform}] ${message}`);
    this.name = 'CapacitorError';
  }
}

async function safeNativeCall<T>(
  plugin: string,
  fn: () => Promise<T>,
  fallback?: T
): Promise<T> {
  try {
    if (!Capacitor.isPluginAvailable(plugin)) {
      if (fallback !== undefined) return fallback;
      throw new CapacitorError(
        'Plugin not available',
        plugin,
        Capacitor.getPlatform()
      );
    }
    return await fn();
  } catch (error) {
    if (error instanceof CapacitorError) throw error;
    const platform = Capacitor.getPlatform();
    if (fallback !== undefined) return fallback;
    throw new CapacitorError(
      error instanceof Error ? error.message : String(error),
      plugin,
      platform
    );
  }
}
```
