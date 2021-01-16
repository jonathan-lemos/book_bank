import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import { round } from 'src/utils/format';
import { sizeUnit } from 'src/utils/size';
import {Result} from "../../utils/functional/result";

@Component({
  selector: 'app-loading',
  templateUrl: './loading.component.html',
  styleUrls: ['./loading.component.sass']
})
export class LoadingComponent implements OnInit {
  @Input() class: string;
  @Input() progress: number | null = null;
  @Input() total: number | null = null;
  _state: "not-loading" | "loading" | "finished" = "not-loading";
  result: Result<string, string> | null = null;
  spinnerPhases = ["|", "/", "-", "\\"];
  spinnerIndex = 0;

  get pctString() {
    if (this.progress === null || this.total === null) {
      return "";
    }
    return `${round(100 * this.progress / this.total, 1)}%`
  }
  

  get spinnerState() {
    return this.spinnerPhases[this.spinnerIndex];
  }

  get state(): "not-loading" | "loading" | "finished" {
    return this._state;
  }

  get stateClass(): string {
    return typeof this.state === "string" ? this.state : "";
  }

  setState(value: "not-loading" | "loading" | Result<string, string>) {
    if (typeof value === "string") {
      this._state = value;
      this.result = null;
    }
    else {
      this._state = "finished";
      this.result = value;
    }

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
      this.setState("loading");

      value.then(r => {
        this.setState(r);
        this.finished.emit(r);
      });
    }
    else {
      this.setState("not-loading");
    }
  }

  @Output() finished = new EventEmitter<Result<string, string>>();
  @Output() closed = new EventEmitter<void>();

  constructor() { }

  close(): void {
    this.setState("not-loading");
    this.closed.emit();
  }

  ngOnInit(): void {
  }
}
