/*
	This file is part of the Microsoft PowerApps code samples. 
	Copyright (C) Microsoft Corporation.  All rights reserved. 
	This source code is intended only as a supplement to Microsoft Development Tools and/or  
	on-line documentation.  See these other materials for detailed information regarding  
	Microsoft code samples. 

	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER  
	EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF  
	MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
 */

import { IInputs, IOutputs } from "./generated/ManifestTypes";

export class IFrameControl implements ComponentFramework.StandardControl<IInputs, IOutputs> {
	// Reference to Bing Map IFrame HTMLElement
	private _iframe: HTMLElement;

	private _Target: string;

	// Reference to the control container HTMLDivElement
	// This element contains all elements of our custom control example
	private _container: HTMLDivElement;

	// Flag if control view has been rendered
	private _controlViewRendered: boolean;

	/**
	 * Used to initialize the control instance. Controls can kick off remote server calls and other initialization actions here.
	 * Data-set values are not initialized here, use updateView.
	 * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to property names defined in the manifest, as well as utility functions.
	 * @param notifyOutputChanged A callback method to alert the framework that the control has new outputs ready to be retrieved asynchronously.
	 * @param state A piece of data that persists in one session for a single user. Can be set at any point in a controls life cycle by calling 'setControlState' in the Mode interface.
	 * @param container If a control is marked control-type='standard', it will receive an empty div element within which it can render its content.
	 */
	public init(
		context: ComponentFramework.Context<IInputs>,
		notifyOutputChanged: () => void,
		state: ComponentFramework.Dictionary,
		container: HTMLDivElement
	): void {
		this._container = container;
		this._controlViewRendered = false;
		
		// Enable container resize tracking to receive allocatedHeight and allocatedWidth in updateView
		context.mode.trackContainerResize(true);
	}

	/**
	 * Called when any value in the property bag has changed. This includes field values, data-sets, global values such as container height and width, offline status, control metadata values such as label, visible, etc.
	 * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to names defined in the manifest, as well as utility functions
	 */
	public updateView(context: ComponentFramework.Context<IInputs>): void {
		if (!this._controlViewRendered) {
			this._controlViewRendered = true;
			this.renderIFrame();
		}

		const iframeSrc = context.parameters.target.raw;

		if (this._Target != iframeSrc) {
			this._Target = iframeSrc ? iframeSrc : "";
			this._iframe.setAttribute("src", this._Target);
		}

		// Update iframe dimensions when container is resized
		if (context.mode.allocatedHeight !== undefined && context.mode.allocatedWidth !== undefined) {
			// Apply allocated dimensions from the parent container
			this._container.style.height = `${context.mode.allocatedHeight}px`;
			this._container.style.width = `${context.mode.allocatedWidth}px`;
		}
	}

	/**
	 * Render IFrame HTML Element that hosts the target and appends the IFrame to the control container
	 */
	// private renderIFrame(): void {
	// 	const iFrameElement: HTMLIFrameElement = document.createElement("iframe");
	// 	iFrameElement.setAttribute("class", "iFrameControl");
	// 	iFrameElement.setAttribute("frameborder", "0");
	// 	this._iframe = iFrameElement;
	// 	this._container.appendChild(this._iframe);
	// }

	/**
	 * Render IFrame HTML Element that hosts the target and appends the IFrame to the control container
	 */
	private renderIFrame(): void {
		const iFrameElement: HTMLIFrameElement = document.createElement("iframe");
		iFrameElement.setAttribute("class", "pcf-ctrl-iframe");
		iFrameElement.setAttribute("frameborder", "0");
		
		// Set iframe to fill the container completely for responsive behavior
		iFrameElement.style.width = "100%";
		iFrameElement.style.height = "100%";
		iFrameElement.style.border = "none";
		
		this._iframe = iFrameElement;
		
		// Ensure the container has proper styling for responsive behavior
		this._container.className = "pcf-ctrl-container";
		this._container.style.width = "100%";
		this._container.style.height = "100%";
		this._container.style.overflow = "hidden";
		
		this._container.appendChild(this._iframe);
	}

	/**
	 * It is called by the framework prior to a control receiving new data.
	 * @returns an object based on nomenclature defined in manifest, expecting object[s] for property marked as "bound" or "output"
	 */
	public getOutputs(): IOutputs {
		// no-op: method not leveraged by this example custom control
		return {};
	}

	/**
	 * Called when the control is to be removed from the DOM tree. Controls should use this call for cleanup.
	 * i.e. cancelling any pending remote calls, removing listeners, etc.
	 */
	public destroy(): void {
		// no-op: method not leveraged by this example custom control
	}
}
