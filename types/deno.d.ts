// Type declarations for TypeScript Language Server in IDE for Deno / Supabase Edge Functions

declare const Deno: {
  env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
  };
  serve(handler: (req: Request) => Promise<Response> | Response): void;
  serve(options: any, handler: (req: Request) => Promise<Response> | Response): void;
  exit(code?: number): never;
  readTextFile(path: string | URL): Promise<string>;
  [key: string]: any;
};

declare module "npm:*" {
  const all: any;
  export = all;
}

declare module "npm:@supabase/supabase-js@2" {
  export const createClient: any;
  export type SupabaseClient = any;
  export type User = any;
}
