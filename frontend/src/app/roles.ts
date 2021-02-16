export enum RoleType {
  Unauthenticated,
  Authenticated,
  Any
}
export type Roles = RoleType | string[];