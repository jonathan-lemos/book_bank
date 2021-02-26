import {ComponentFixture} from "@angular/core/testing";

export function queryElement<T extends HTMLElement>(fixture: ComponentFixture<any>, selector: string): T | null {
  return (fixture.nativeElement as HTMLElement).querySelector<T>(selector);
}

export function elementExists(fixture: ComponentFixture<any>, selector: string): boolean {
  return queryElement(fixture, selector) !== null;
}
