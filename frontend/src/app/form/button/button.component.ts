import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';

@Component({
  selector: 'app-button',
  templateUrl: './button.component.html',
  styleUrls: ['./button.component.sass']
})
export class ButtonComponent implements OnInit {
  @Input() text: string = "";
  @Input() disabled = false;
  @Output() click = new EventEmitter<void>();

  constructor() { }

  ngOnInit(): void {
  }

}
