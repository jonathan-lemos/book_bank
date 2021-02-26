import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faTrash} from '@fortawesome/free-solid-svg-icons';
import {mapToList} from 'src/utils/misc';

@Component({
  selector: 'app-key-value-editor',
  templateUrl: './key-value-editor.component.html',
  styleUrls: ['./key-value-editor.component.sass']
})
export class KeyValueEditorComponent implements OnInit {
  @Input() keyValuePairs: { [key: string]: string } = {}
  @Output() keyValuePairsChange = new EventEmitter<{ [key: string]: string }>();

  internalKeyValueListing: { key: string, value: string, new: boolean }[] = [];

  constructor(library: FaIconLibrary) {
    library.addIcons(faTrash);
  }

  outputInternalKeyValueListing() {
    this.keyValuePairsChange.emit(
      this.internalKeyValueListing
        .filter(x => x.key !== "" && x.value !== "")
        .reduce((a, c) => Object.assign(a, {[c.key]: c.value}), {})
    );
  }

  afterMutateKvp(index: number) {
    if (index >= this.internalKeyValueListing.length - 1) {
      this.addKvp();
    }

    this.outputInternalKeyValueListing();
  }

  addKvp() {
    this.internalKeyValueListing.push({key: "", value: "", new: true});
  }

  deleteKvp(index: number) {
    this.internalKeyValueListing.splice(index, 1);
    this.outputInternalKeyValueListing();
  }

  placeholderKey(initialKey: string) {
    return initialKey === "" ? "[key]" : initialKey;
  }

  placeholderValue(initialValue: string) {
    return initialValue === "" ? "[value]" : initialValue;
  }

  ngOnInit(): void {
    this.internalKeyValueListing = mapToList(this.keyValuePairs).map(x => ({...x, new: false}));
    this.addKvp();
  }
}
