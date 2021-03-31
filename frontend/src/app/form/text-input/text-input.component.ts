import {Component, Input, OnInit, EventEmitter, Output, ViewChild, ElementRef, AfterViewInit} from '@angular/core';
import {sleep} from "../../../utils/misc";

@Component({
  selector: 'app-text-input',
  templateUrl: './text-input.component.html',
  styleUrls: ['./text-input.component.sass']
})
export class TextInputComponent implements OnInit, AfterViewInit {
  @Input() type: "text" | "password" = "text";
  @Input() value: string = "";
  @Input() prompt: string = "password> ";
  @Output() valueChange = new EventEmitter<string>();
  @Output() enter = new EventEmitter<void>();

  @ViewChild("inputElement") inputEl: ElementRef | undefined;

  constructor(private elRef: ElementRef) { }

  handleInput(event: KeyboardEvent) {
    const ct = event?.currentTarget;
    if (!(ct instanceof HTMLElement)) {
      return;
    }

    if (event.key === "Enter") {
      this.enter.emit();
    }
  }

  focusInput() {
    const el = this.inputEl?.nativeElement;
    if (el == null || !(el instanceof HTMLElement)) {
      return;
    }

    el.focus();
  }

  ngOnInit(): void {
  }

  ngAfterViewInit(): void {
    if (!(this.elRef.nativeElement instanceof HTMLElement)) {
      return;
    }

    this.elRef.nativeElement.onclick = this.focusInput.bind(this);
  }
}
