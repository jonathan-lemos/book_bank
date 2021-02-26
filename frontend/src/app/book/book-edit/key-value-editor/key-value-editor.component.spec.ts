import {ComponentFixture, discardPeriodicTasks, fakeAsync, flush, TestBed, tick} from '@angular/core/testing';
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
