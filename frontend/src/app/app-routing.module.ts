import { NgModule } from '@angular/core';
import { Data, Route, RouterModule } from '@angular/router';
import { LoginComponent } from "./login/login.component";
import { HomeComponent } from "./home/home.component";
import { SearchComponent } from "./search/search/search.component";
import { UploadComponent } from "./upload/upload.component";
import { AuthService } from "./services/auth.service";
import { Roles, RoleType } from './roles';
import { BookComponent } from './book/book.component';

export type RoutingEntry = {
  route: Route & { data: Data, path: string },
  auth: { name: string } & Partial<{ putInNavbar: boolean, roles: Roles }>
}

export const routingEntries: RoutingEntry[] = [
  {
    route: { path: "login", component: LoginComponent, canActivate: [AuthService] },
    auth: { name: "Login", putInNavbar: true, roles: RoleType.Unauthenticated }
  },
  {
    route: { path: "home", component: HomeComponent, canActivate: [AuthService] },
    auth: { name: "Home", putInNavbar: true, roles: RoleType.Authenticated }
  },
  {
    route: { path: "search", component: SearchComponent, canActivate: [AuthService] },
    auth: { name: "Search", putInNavbar: false, roles: RoleType.Authenticated }
  },
  {
    route: { path: "upload", component: UploadComponent, canActivate: [AuthService] },
    auth: { name: "Upload", putInNavbar: true, roles: ["admin", "librarian"] }
  },
  {
    route: { path: "book", component: BookComponent, canActivate: [AuthService] },
    auth: { name: "Book", putInNavbar: false, roles: RoleType.Authenticated }
  },
  {
    route: { path: "**", redirectTo: "home", pathMatch: "full" },
    auth: { name: "Default", putInNavbar: false, roles: RoleType.Any }
  }
].map(x => ({ auth: x.auth, route: { ...x.route, data: x.auth } }))

const routes: Route[] = routingEntries.map(x => x.route);

@NgModule({
  imports: [RouterModule.forRoot(routes, { relativeLinkResolution: 'legacy' })],
  exports: [RouterModule]
})
export class AppRoutingModule { }
