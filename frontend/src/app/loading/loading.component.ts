import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import { sizeUnit } from 'src/utils/size';
import {Result} from "../../utils/functional/result";

@Component({
  selector: 'app-loading',
  templateUrl: './loading.component.html',
  styleUrls: ['./loading.component.sass']
})
export class LoadingComponent implements OnInit {
  @Input() class: string;
  _state: "not-loading" | "loading" | "finished" = "not-loading";
  result: Result<string, string> | null = null;
  spinnerPhases = ["|", "/", "-", "\\"];
  spinnerIndex = 0;
  pctString = "";

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

  @Input() set promise(value: Promise<Result<string, string>> | {promise: Promise<Result<string, string>>, progressCallbackRegistrationFunction: (cb: (progress: number, total: number) => void) => void} | null) {
    if (this.state === "loading") {
      return;
    }

    if (value !== null) {
      let prom: Promise<Result<string, string>>;
      if ("promise" in value && "progressCallbackRegistrationFunction" in value) {
        prom = value.promise;
        value.progressCallbackRegistrationFunction((progress, total) => this.pctString = `${sizeUnit(progress).join(" ")}/${sizeUnit(total).join(" ")} (${Math.round(progress / total * 100)}%)`);
      }
      else {
        prom = value;
      }

      this.setState("loading");

      prom.then(r => {
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
