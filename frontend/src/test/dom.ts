import {ComponentFixture, tick} from "@angular/core/testing";

export function queryElement<T extends HTMLElement>(fixture: ComponentFixture<any>, selector: string): T | null {
  return (fixture.nativeElement as HTMLElement).querySelector<T>(selector);
}

export function queryElements<T extends HTMLElement>(fixture: ComponentFixture<any>, selector: string): T[] {
  const nodeList = (fixture.nativeElement as HTMLElement).querySelectorAll<T>(selector);
  const ret: T[] = [];

  nodeList.forEach(x => ret.push(x));

  return ret;
}

export function elementExists(fixture: ComponentFixture<any>, selector: string): boolean {
  return queryElement(fixture, selector) !== null;
}

export function waitForComponentChanges(fixture: ComponentFixture<any>): void {
  // angular fucking sucks

  // the first one is to run ngOnInit()
  tick();
  fixture.detectChanges();
  // the second one is to actually finish it
  tick();
  fixture.detectChanges();
}
