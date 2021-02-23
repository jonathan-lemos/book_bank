import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { mapToList } from 'src/utils/misc';

@Component({
  selector: 'app-key-value-editor',
  templateUrl: './key-value-editor.component.html',
  styleUrls: ['./key-value-editor.component.sass']
})
export class KeyValueEditorComponent implements OnInit {
  @Input() keyValuePairs: { [key: string]: string }
  @Output() keyValuePairsChange = new EventEmitter<{ [key: string]: string }>();

  internalKeyValueListing: { key: string, value: string, new: boolean }[];

  outputInternalKeyValueListing() {
    this.keyValuePairsChange.emit(
      this.internalKeyValueListing
        .filter(x => x.key !== "" && x.value !== "")
        .reduce((a, c) => Object.assign(a, { [c.key]: c.value }), {})
    );
  }

  mutateKvpEvent(index: number, event: KeyboardEvent, fn: (object: { key: string, value: string, new: boolean }, text: string) => void) {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }

    fn(this.internalKeyValueListing[index], event.currentTarget.value);

    if (index >= this.internalKeyValueListing.length - 1) {
      this.addKvp();
    }

    this.outputInternalKeyValueListing();
  }

  setKvpKey(index: number, event: KeyboardEvent) {
    this.mutateKvpEvent(index, event, (obj, text) => obj.key = text);
  }

  setKvpValue(index: number, event: KeyboardEvent) {
    this.mutateKvpEvent(index, event, (obj, text) => obj.value = text);
  }

  addKvp() {
    this.internalKeyValueListing.push()
  }

  deleteKvp(index: number) {
    this.internalKeyValueListing = this.internalKeyValueListing.splice(index, 1);
  }

  placeholderKey(initialKey: string) {
    initialKey === "" ? "[key]" : initialKey;
  }

  placeholderValue(initialValue: string) {
    initialValue === "" ? "[value]" : initialValue;
  }

  constructor() {
  }

  ngOnInit(): void {
    this.internalKeyValueListing = mapToList(this.keyValuePairs).map(x => ({ ...x, new: false }));
  }
}
