


function [fig_handle, exit_method] = situate_parameters_adjust_gui(p)



    if ~exist('p','var') || isempty(p)
        p = situate_parameters_initialize();
    end
    
    % set up spacing for the ui controls
        m = 9; % items per column
        step = 65; % pixels between entry
        
        screen_size = get(groot,'ScreenSize');
        handles.figure = figure();
        set(handles.figure, 'Name', 'Situate parameters');
        set(handles.figure, 'MenuBar', 'none');
        set(handles.figure, 'ToolBar', 'none');

        fig_height = m*step + 50; % extra 20 roughly for the top bar
        fig_width  = 600;
        set(handles.figure,'OuterPosition',[50 (screen_size(4)-fig_height-24-50) fig_width fig_height]);
        
        fig_handle = handles.figure;
        figure_position_vect = get( handles.figure, 'Position');
        fig_top = figure_position_vect(4);
        positions(1:m,:)     = repmat([ 50 fig_top-step 200 20 ],m,1) - [zeros(m,1) (0:step:step*(m-1))' zeros(m,1) zeros(m,1) ];
        positions(m+1:2*m,:) = repmat([ 350 fig_top-step 200 20 ],m,1) - [zeros(m,1) (0:step:step*(m-1))' zeros(m,1) zeros(m,1) ];

        
        
    % get the existing values for each setting from the p struct
        ind_location_method_before              = find( strcmp( p.location_method_before_conditioning,          p.location_method_options_before ) );
        ind_location_method_after               = find( strcmp( p.location_method_after_conditioning,           p.location_method_options_after ) );
        ind_location_sampling_method_before     = find( strcmp( p.location_sampling_method_before_conditioning, p.location_sampling_method_options ) );
        ind_location_sampling_method_after      = find( strcmp( p.location_sampling_method_after_conditioning,  p.location_sampling_method_options ) );
        ind_inhibition_method                   = find( strcmp( p.inhibition_method,                            p.inhibition_method_options ) );
        ind_box_method_before                   = find( strcmp( p.box_method_before_conditioning,               p.box_method_options_before ) );
        ind_box_method_after                    = find( strcmp( p.box_method_after_conditioning,                p.box_method_options_after ) );
        ind_classification_method               = find( strcmp( p.classification_method,                        p.classification_options ) );
        
    cur_position_ind = 1;
    cur_label = 'location distribution, before';
    options = p.location_method_options_before;
    starting_ind = ind_location_method_before;
    handles.location_method_before = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 2;
    cur_label = 'location distribution, after';
    options = p.location_method_options_after;
    starting_ind = ind_location_method_after;
    handles.location_method_after = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 3;
    cur_label = 'location sampling method, before';
    options = p.location_sampling_method_options;
    starting_ind = ind_location_sampling_method_before;
    handles.sampling_method_before = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 4;
    cur_label = 'location sampling method, after';
    options = p.location_sampling_method_options;
    starting_ind = ind_location_sampling_method_after;
    handles.sampling_method_after = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 5;
    cur_label = 'inhibition method';
    options = p.inhibition_method_options;
    options{ strcmp('blackman',options) } = 'Gaussian';
    starting_ind = ind_inhibition_method;
    handles.inhibition_method = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 6;
    text_inhibition_diameter_slider = 'inhibition diameter: ';
    starting_val = p.inhibition_size;
    min_val = 0;
    max_val = 200;
    handles.inhibition_diameter_text     = uicontrol( 'Style', 'text', 'String',[text_inhibition_diameter_slider num2str(starting_val)], 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    handles.inhibition_diameter_slider   = uicontrol( 'Style', 'slider', 'Position', positions(cur_position_ind,:), 'Min', min_val, 'Max', max_val, 'Value', starting_val );
    event_listeners.inhibition_diameter_slider_listener = addlistener( handles.inhibition_diameter_slider, 'Value', 'PostSet', @(s,e) set(handles.inhibition_diameter_text,'String',[text_inhibition_diameter_slider num2str(round(get(handles.inhibition_diameter_slider,'Value')))]) );

    cur_position_ind = 7;
    text_inhibition_intensity_slider = 'inhibition intensity: ';
    starting_val = p.inhibition_intensity;
    min_val = 0;
    max_val = 1;
    handles.inhibition_intensity_text     = uicontrol( 'Style', 'text', 'String',[text_inhibition_intensity_slider num2str(starting_val)], 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    handles.inhibition_intensity_slider   = uicontrol( 'Style', 'slider', 'Position', positions(cur_position_ind,:), 'Min', min_val, 'Max', max_val, 'Value', starting_val);
    event_listeners.inhibition_intensity_slider_listener = addlistener( handles.inhibition_intensity_slider, 'Value', 'PostSet', @(s,e) set(handles.inhibition_intensity_text,'String',[text_inhibition_intensity_slider num2str(get(handles.inhibition_intensity_slider,'Value'))]) );

    cur_position_ind = 8;
    cur_label = 'box sampling method, before';
    options = p.box_method_options_before;
    starting_ind = ind_box_method_before;
    handles.box_method_before = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 9;
    cur_label = 'box sampling method, after';
    options = p.box_method_options_after;
    starting_ind = ind_box_method_after;
    handles.box_method_after = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 10;
    text_agent_iterations_slider = 'agent iterations to run: ';
    starting_val = p.num_iterations;
    min_val = 1;
    max_val = 10000;
    handles.agent_iterations_text     = uicontrol( 'Style', 'text', 'String',[text_agent_iterations_slider num2str(starting_val)], 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    handles.agent_iterations_slider   = uicontrol( 'Style', 'slider', 'Position', positions(cur_position_ind,:), 'Min', min_val, 'Max', max_val, 'Value', starting_val);
    event_listeners.agent_iterations_slider_listener = addlistener( handles.agent_iterations_slider, 'Value', 'PostSet', @(s,e) set(handles.agent_iterations_text,'String',[text_agent_iterations_slider num2str(round(handles.agent_iterations_slider.Value))]) );
    
    cur_position_ind = 11;
    cur_label = 'internal support method';
    options = p.classification_options;
    starting_ind = ind_classification_method;
    handles.classification_method = uicontrol( 'Style', 'popupmenu', 'String', options, 'Position', positions(cur_position_ind,:), 'Value', starting_ind );
    handles.a = uicontrol( 'Style', 'text', 'String',cur_label, 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    
    cur_position_ind = 12;
    text_checkin_threshold_1_slider = 'workspace threshold - provisional: ';
    starting_val = p.thresholds.total_support_provisional;
    min_val = 0;
    max_val = 1;
    handles.checkin_threshold_1_text   = uicontrol( 'Style', 'text',   'String',[text_checkin_threshold_1_slider num2str(starting_val)], 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    handles.checkin_threshold_1_slider = uicontrol( 'Style', 'slider', 'Position', positions(cur_position_ind,:), 'Min', min_val, 'Max', max_val, 'Value', starting_val);
    event_listeners.checkin_threshold_1_slider_listener = addlistener( handles.checkin_threshold_1_slider, 'Value', 'PostSet', @(s,e) set(handles.checkin_threshold_1_text,'String',[text_checkin_threshold_1_slider num2str(handles.checkin_threshold_1_slider.Value, 3)]) );
    
    cur_position_ind = 13;
    text_checkin_threshold_2_slider = 'workspace threshold - commit: ';
    starting_val = p.thresholds.total_support_final;
    min_val = 0;
    max_val = 1;
    handles.checkin_threshold_2_text   = uicontrol( 'Style', 'text',   'String',[text_checkin_threshold_2_slider num2str(starting_val)], 'HorizontalAlignment','Left', 'Position', positions(cur_position_ind,:) + [0 20 0 0] );
    handles.checkin_threshold_2_slider = uicontrol( 'Style', 'slider', 'Position', positions(cur_position_ind,:), 'Min', min_val, 'Max', max_val, 'Value', starting_val);
    event_listeners.checkin_threshold_2_slider_listener = addlistener( handles.checkin_threshold_2_slider, 'Value', 'PostSet', @(s,e) set(handles.checkin_threshold_2_text,'String',[text_checkin_threshold_2_slider num2str(handles.checkin_threshold_2_slider.Value, 3)]) );
    
    cur_position_ind = 14;
    handles.apply_button = uicontrol( 'Style', 'pushbutton', 'String', 'Apply', 'Position', positions(end,:), 'Callback', {@apply_changes, p, handles} );
  
    
    
end



function apply_changes( hObject, callbackdata, p, handles  )

    p.location_method_before_conditioning = p.location_method_options_before{ get(handles.location_method_before,'Value') };
    p.location_method_after_conditioning  = p.location_method_options_after{  get(handles.location_method_after,'Value') };

    p.location_sampling_method_before_conditioning = p.location_sampling_method_options{ get(handles.sampling_method_before,'Value') };
    p.location_sampling_method_after_conditioning  = p.location_sampling_method_options{ get(handles.sampling_method_after,'Value')  };

    
    p.box_method_before_conditioning = p.box_method_options_before{ get(handles.box_method_before,'Value') };
    p.box_method_after_conditioning  = p.box_method_options_after{  get(handles.box_method_after,'Value')  };

    
    p.inhibition_intensity = get(handles.inhibition_intensity_slider,'Value');
    p.inhibition_method    = p.inhibition_method_options{ get(handles.inhibition_method,'Value')};
    p.inhibition_size      = round( get(handles.inhibition_diameter_slider,'Value') );

    p.num_iterations = round( get(handles.agent_iterations_slider,'Value') );

    p.classification_method                 = p.classification_options{ get(handles.classification_method,'Value')};
    p.thresholds.total_support_provisional  = get(handles.checkin_threshold_1_slider,'Value');
    p.thresholds.total_support_final        = get(handles.checkin_threshold_2_slider,'Value');
    
    % edit: dumb ol' hack because lordy matlab
    save('temp_situate_parameters_struct.mat','-struct','p');
    
    close(handles.figure);
    
end
    


% % http://www.mathworks.com/help/matlab/ref/uicontrol.html
% % http://stackoverflow.com/questions/6032924/in-matlab-how-can-you-have-a-callback-execute-while-a-slider-is-being-dragged
% % http://www.mathworks.com/help/matlab/ref/uicontrol-properties.html









