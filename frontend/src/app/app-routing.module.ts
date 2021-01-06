import {NgModule} from '@angular/core';
import {Route, RouterModule} from '@angular/router';
import {LoginComponent} from "./login/login.component";
import {HomeComponent} from "./home/home.component";
import {SearchComponent} from "./search/search/search.component";
import {UploadComponent} from "./upload/upload.component";
import {AuthService} from "./services/auth.service";

export type Roles = "no-auth" | "auth" | "*" | string[];

export const routes: (Route & {
  path: string,
  name: string,
  putInNavbar: boolean,
  roles: Roles,
  data: { roles: Roles },
  canActivate: any[]
})[] = [
  {path: "login", name: "Login", component: LoginComponent, putInNavbar: true, roles: "no-auth"},
  {path: "home", name: "Home", component: HomeComponent, putInNavbar: true, roles: "auth"},
  {path: "search", name: "Search", component: SearchComponent, putInNavbar: true, roles: "auth"},
  {path: "upload", name: "Upload", component: UploadComponent, putInNavbar: true, canActivate: [AuthService], roles: ["admin", "librarian"]},
  {path: "**", name: "Default", putInNavbar: false, redirectTo: "home", pathMatch: "full", roles: "*"}
].map(x => ({...x, roles: x.roles as Roles, data: {roles: x.roles as Roles}, canActivate: [AuthService]}));

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
