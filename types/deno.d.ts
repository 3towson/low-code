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

interface SupabaseRpcFilterBuilder {
  single<T = any>(): Promise<{ data: T | null; error: any }>;
  maybeSingle<T = any>(): Promise<{ data: T | null; error: any }>;
  [key: string]: any;
}

interface SupabaseQueryBuilder {
  select<T = any>(columns?: string): SupabaseQueryBuilder & Promise<{ data: T | null; error: any }>;
  insert<T = any>(values: any): SupabaseQueryBuilder & Promise<{ data: T | null; error: any }>;
  update<T = any>(values: any): SupabaseQueryBuilder & Promise<{ data: T | null; error: any }>;
  delete<T = any>(): SupabaseQueryBuilder & Promise<{ data: T | null; error: any }>;
  eq(column: string, value: any): SupabaseQueryBuilder;
  in(column: string, values: any[]): SupabaseQueryBuilder;
  single<T = any>(): Promise<{ data: T | null; error: any }>;
  maybeSingle<T = any>(): Promise<{ data: T | null; error: any }>;
  [key: string]: any;
}

interface SupabaseClientInstance {
  from(table: string): SupabaseQueryBuilder;
  rpc(fn: string, args?: Record<string, any>): SupabaseRpcFilterBuilder;
  auth: any;
  storage: any;
  [key: string]: any;
}

declare module "npm:*" {
  const all: any;
  export = all;
}

declare module "npm:@supabase/supabase-js@2" {
  export const createClient: (
    supabaseUrl: string,
    supabaseKey: string,
    options?: any,
  ) => SupabaseClientInstance;
  export type SupabaseClient = SupabaseClientInstance;
  export type User = any;
}
