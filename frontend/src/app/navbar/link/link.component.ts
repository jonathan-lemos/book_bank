import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';

@Component({
  selector: 'app-link',
  templateUrl: './link.component.html',
  styleUrls: ['./link.component.sass']
})
export class LinkComponent implements OnInit {

  @Input() href: string;
  @Input() title: string;
  @Input() active: boolean;
  @Output() click = new EventEmitter<string>();

  constructor() { }

  ngOnInit(): void {
  }

}
