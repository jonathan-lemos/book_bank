import { ComponentFixture, TestBed } from '@angular/core/testing';

import { KeyValueEditorComponent } from './key-value-editor.component';

describe('KeyValueEditorComponent', () => {
  let component: KeyValueEditorComponent;
  let fixture: ComponentFixture<KeyValueEditorComponent>;
  let pairs = {
    Author: "Dr. Seuss",
    ISBN: "0123456789"
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [KeyValueEditorComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(KeyValueEditorComponent);
    component = fixture.componentInstance;
    component.keyValuePairs = pairs;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should echo', done => {
    component.keyValuePairsChange.subscribe(value => {
      expect(value).toEqual(pairs);
      done();
    });

    component.outputInternalKeyValueListing();
  });
});
