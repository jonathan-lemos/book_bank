import {Component, EventEmitter, Input, OnChanges, OnInit, Output, SimpleChanges} from '@angular/core';
import {Result} from "../../utils/functional/result";

@Component({
  selector: 'app-loading',
  templateUrl: './loading.component.html',
  styleUrls: ['./loading.component.sass']
})
export class LoadingComponent implements OnInit {
  @Input() class: string;
  _state: "not-loading" | "loading" | Result<string, string> = "not-loading";
  spinnerPhases = ["|", "/", "-", "\\"];
  spinnerIndex = 0;

  get spinnerState() {
    return this.spinnerPhases[this.spinnerIndex];
  }

  get state() {
    return this._state;
  }

  set state(value: "not-loading" | "loading" | Result<string, string>) {
    this._state = value;
    if (value === "loading") {
        (async () => {
          while (this.state === "loading") {
            await new Promise(res => setTimeout(res, 250));
            this.spinnerIndex = (this.spinnerIndex + 1) % this.spinnerPhases.length;
          }
        })();
    }
  }

  @Input() set promise(value: Promise<Result<string, string>> | null) {
    if (this.state === "loading") {
      return;
    }

    if (value !== null) {
      this.state = "loading";

      value.then(r => {
        this.state = r;
        this.finished.emit(r);
      });
    }
    else {
      this.state = "not-loading";
    }
  }

  @Output() finished = new EventEmitter<Result<string, string>>();
  @Output() closed = new EventEmitter<void>();

  constructor() { }

  close(): void {
    this.state = "not-loading";
    this.closed.emit();
  }

  ngOnInit(): void {
  }

  isFinished(): boolean {
    return this.promise instanceof Result;
  }

}
