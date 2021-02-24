import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faTimes} from '@fortawesome/free-solid-svg-icons';
import {round} from 'src/utils/format';
import {Result} from "../../utils/functional/result";

@Component({
  selector: 'app-loading',
  templateUrl: './loading.component.html',
  styleUrls: ['./loading.component.sass']
})
export class LoadingComponent implements OnInit {
  @Input() progress: number | null = null;
  @Input() total: number | null = null;
  result: Result<string, string> | null = null;
  spinnerPhases = ["|", "/", "-", "\\"];
  spinnerIndex = 0;
  @Output() finished = new EventEmitter<Result<string, string>>();
  @Output() closed = new EventEmitter<void>();

  constructor(private library: FaIconLibrary) {
    library.addIcons(faTimes);
  }

  _state: "not-loading" | "loading" | "finished" = "not-loading";

  get state(): "not-loading" | "loading" | "finished" {
    return this._state;
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
    } else {
      this.setState("not-loading");
    }
  }

  get outerClass() {
    return `outer ${this.stateClass}`
  }

  get innerClass() {
    return `inner ${this.stateClass}`
  }

  get pctString() {
    if (this.progress === null || this.total === null) {
      return "";
    }
    return `${round(100 * this.progress / this.total, 1)}%`
  }

  get spinnerState() {
    return this.spinnerPhases[this.spinnerIndex];
  }

  get stateClass(): string {
    return typeof this.state === "string" ? this.state : "";
  }

  setState(value: "not-loading" | "loading" | Result<string, string>) {
    if (typeof value === "string") {
      this._state = value;
      this.result = null;
    } else {
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

  close(e?: MouseEvent): void {
    if (this.state !== "finished") {
      return;
    }

    if (e && e.target !== e.currentTarget) {
      return;
    }

    this.setState("not-loading");
    this.closed.emit();
  }

  ngOnInit(): void {
  }
}
