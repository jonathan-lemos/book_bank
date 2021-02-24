import {DebugElement} from '@angular/core';
import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {FormsModule} from '@angular/forms';
import {By} from '@angular/platform-browser';
import {FaIconLibrary, FontAwesomeModule} from '@fortawesome/angular-fontawesome';

import {KeyValueEditorComponent} from './key-value-editor.component';

describe('KeyValueEditorComponent', () => {
  let component: KeyValueEditorComponent;
  let fixture: ComponentFixture<KeyValueEditorComponent>;
  let pairs = {
    Author: "Dr. Seuss",
    ISBN: "0123456789"
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [KeyValueEditorComponent],
      imports: [FormsModule, FontAwesomeModule],
      providers: [FaIconLibrary]
    })
      .compileComponents();
  });

  beforeEach(fakeAsync(() => {
    fixture = TestBed.createComponent(KeyValueEditorComponent);
    component = fixture.componentInstance;
    component.keyValuePairs = pairs;
    fixture.detectChanges();
    tick();
  }));

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

  it('should add a row', done => {
    const expected = {...pairs, Test: "Value"};

    component.addKvp();
    const lastIndex = component.internalKeyValueListing.length - 1;

    component.internalKeyValueListing[lastIndex].key = "Test";
    component.internalKeyValueListing[lastIndex].value = "Value";

    component.keyValuePairsChange.subscribe(value => {
      expect(value).toEqual(expected);
      done();
    });

    component.outputInternalKeyValueListing();
  });

  it('should remove a row', done => {
    let remainingValue = component.internalKeyValueListing[1];
    let expected = {[remainingValue.key]: remainingValue.value};

    component.deleteKvp(0);

    component.keyValuePairsChange.subscribe(value => {
      expect(value).toEqual(expected);
      done();
    });

    component.outputInternalKeyValueListing();
  });

  it('should not output blank row', done => {
    const expected = pairs;

    component.addKvp();
    const lastIndex = component.internalKeyValueListing.length - 1;

    component.keyValuePairsChange.subscribe(value => {
      expect(value).toEqual(expected);
      done();
    });

    component.internalKeyValueListing[lastIndex].key = "Test";
    component.afterMutateKvp(lastIndex);
  });

  const numRows = () => {
    const rows = [...fixture.debugElement.queryAll(By.css(".kvp-row"))];
    return rows.length;
  }

  const getRow = (i: number): DebugElement => {
    const rows = [...fixture.debugElement.queryAll(By.css(".kvp-row"))];
    return rows[i];
  };

  const lastRow = (): DebugElement => {
    return getRow(numRows() - 1);
  };

  const setRowFields = async (row: DebugElement, update: Partial<{ key: string, value: string }>) => {
    fixture.detectChanges();

    for (const key in update) {
      switch (key) {
        case "key": {
          let input = row.query(By.css(".key"));
          input.nativeElement.value = update.key;
          input.nativeElement.dispatchEvent(new Event("input"));
        }
          break;
        case "value": {
          let input = row.query(By.css(".value"));
          input.nativeElement.value = update.value;
          input.nativeElement.dispatchEvent(new Event("input"));
        }
          break;
        default:
          break;
      }
      tick();
      fixture.detectChanges();
      await fixture.whenStable();
    }
  };

  it('should add new row upon modifying last row', fakeAsync(async () => {
    const spy = spyOn(component, 'afterMutateKvp').and.callThrough();

    const numRowsStart = Object.keys(pairs).length + 1;

    expect(numRows()).toBe(numRowsStart);

    await setRowFields(lastRow(), {key: "Aids"});

    tick();

    expect(spy).toHaveBeenCalledWith(numRowsStart - 1);

    expect(component.internalKeyValueListing[numRowsStart - 1].key).toEqual("Aids");

    expect(numRows()).toBe(numRowsStart + 1);
  }));
});
