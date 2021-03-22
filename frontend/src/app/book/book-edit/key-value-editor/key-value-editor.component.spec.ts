import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {FormsModule} from '@angular/forms';
import {By} from '@angular/platform-browser';
import {FaIconLibrary, FontAwesomeModule} from '@fortawesome/angular-fontawesome';

import {KeyValueEditorComponent} from './key-value-editor.component';
import {waitForComponentChanges} from "../../../../test/dom";

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
    waitForComponentChanges(fixture);
  }));

  const numRows = () => {
    const rows = [...fixture.debugElement.queryAll(By.css(".kvp-row"))];
    return rows.length;
  }

  const getRow = (i: number): HTMLDivElement => {
    const rows = [...fixture.debugElement.queryAll(By.css(".kvp-row"))];
    return rows[i].nativeElement;
  };

  const lastRow = (): HTMLDivElement => {
    return getRow(numRows() - 1);
  };

  const setRowFields = (row: HTMLDivElement, update: Partial<{ key: string, value: string }>) => {
    fixture.detectChanges();

    if (update.key !== undefined) {
      let input = row.querySelector<HTMLInputElement>(".key")!;
      input.value = update.key;
      input.dispatchEvent(new Event("input"));
    }
    if (update.value !== undefined) {
      let input = row.querySelector<HTMLInputElement>(".value")!;
      input.value = update.value;
      input.dispatchEvent(new Event("input"));
    }

    tick();
    fixture.detectChanges();
    tick();
  };

  /*

  keyValuePairAssertion((when, then) => {
    let exp = {a: 4, b: 5};

    when(() => {
      let foo = 8 * 4;
      setRow(0, {value: foo});
      return foo;
    });

    then((pairs, value)) => {
       expect(pairs[0].value).toBe(value);
    });

  })

   */

  function keyValuePairAssertion<T>(given: (when: (fn: () => T) => T, then: (fn: (pairs: typeof component.keyValuePairs, value?: T) => void) => void) => void) {
    return (done: DoneFn) => fakeAsync(() => {
      let whenResult: T | undefined;

      let kvpChanges: (typeof component.keyValuePairs)[] = [];

      component.keyValuePairsChange.subscribe(pairs => kvpChanges.push(pairs));

      const whenHook = (fn: () => T): T => {
        whenResult = fn();

        waitForComponentChanges(fixture);
        tick();

        return whenResult;
      };

      const thenHook = (fn: (pairs: typeof component.keyValuePairs, value?: T) => void) => {
        if (kvpChanges.length === 0) {
          kvpChanges.push(component.keyValuePairs);
        }

        fn(kvpChanges[kvpChanges.length - 1], whenResult);
        done();
      };

      given(whenHook, thenHook);
    })();
  }

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should echo', keyValuePairAssertion((when, then) => {
    when(() => component.outputInternalKeyValueListing());
    then(value => expect(value).toEqual(pairs));
  }));

  it('should add a row', keyValuePairAssertion((when, then) => {
    const [testKey, testValue] = ["Test", "Value"];

    when(() => {
      component.addKvp();

      component.internalKeyValueListing.last.key = testKey;
      component.internalKeyValueListing.last.value = testValue;

      component.outputInternalKeyValueListing();
    });

    then(value => {
      expect(value).toEqual({...pairs, [testKey]: testValue});
    });
  }));


  it('should remove a row', keyValuePairAssertion((when, then) => {
    let remainingValue = component.internalKeyValueListing[1];
    let expected = {[remainingValue.key]: remainingValue.value};

    when(() => {
      component.deleteKvp(0);
    });

    then(value => {
      expect(value).toEqual(expected);
    });
  }));

  it('should not output blank row', keyValuePairAssertion((when, then) => {
    const expected = pairs;

    when(() => {
      component.addKvp();
      component.internalKeyValueListing.last.key = "Test";
      component.afterMutateKvp(component.internalKeyValueListing.length - 1);
    });

    then(value => expect(value).toEqual(expected));
  });

  it('should add new row upon modifying last row', fakeAsync(async () => {
    const numRowsStart = Object.keys(pairs).length + 1;
    expect(numRows()).toBe(numRowsStart);

    setRowFields(lastRow(), {key: "Aids"});

    expect(component.internalKeyValueListing[numRowsStart - 1].key).toEqual("Aids");
    expect(numRows()).toBe(numRowsStart + 1);
  }));

  it('should delete row upon clicking delete button', fakeAsync(() => {
    const spy = spyOn(component, "deleteKvp");

    getRow(1).querySelector<HTMLElement>("fa-icon")!.click();

    tick();

    expect(spy).toHaveBeenCalledWith(1);
  }));

  it('should modify a row correctly', done => fakeAsync(() => {
    const spy = spyOn(component, "outputInternalKeyValueListing").and.callThrough();

    setRowFields(getRow(1), {key: "ABC", value: "DEF"});

    expect(spy).toHaveBeenCalled();

    component.keyValuePairsChange.subscribe(value => {
      expect(value["ABC"]).toBe("DEF");
      expect(Object.keys(value).length).toBe(Object.keys(pairs).length);
      done();
    });

    component.outputInternalKeyValueListing();
  })());
});
