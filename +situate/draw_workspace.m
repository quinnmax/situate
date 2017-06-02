

function h = draw_workspace( input, p, workspace, font_size )

    % handle_array = situate.draw_workspace( input, p, workspace )
    %
    %   h is the handle to the output figure, specifically the image
    %   input can be an image fname, an image matrix, 
    %       or a handle to an exisiting image
    %       if empty, just draws into current axes
    %   p is a situate parameters structure
    %   workspace is the situate workspace to draw
   
    bounding_box_format_provisional = 'r--';
    bounding_box_format_final = 'r';
    
    h = [];
    
    if ~exist('font_size','var')
        font_size = 8;
    end
    
    %% figure out what the input was 
    %   might be an image fname, an image matrix, or a handle to an existing figure
    %   if empty, then just draws into current axes without trying to switch anything around
        
        if ~isempty(input)
            switch class(input)
                case 'char'
                    x = imresize_px( imread(input), p.image_redim_px );
                    h(1) = imshow( x, [] );
                case 'double'
                    if all(ishandle(input))
                        axes(input);
                    else
                        x = imresize_px( input, p.image_redim_px );
                        h(1) = imshow( x, [] );
                    end
                case 'matlab.graphics.axis.Axes'
                    axes(input);
                case 'matlab.ui.Figure'
                    axes(input.CurrentAxes);
                otherwise
                    error('situate_draw_workspace doesn''t recognize the input provided');
            end
        end

        
        
    %% draw workspace boxes onto main image
    
        hold on;
        for wi = 1:size(workspace.boxes_r0rfc0cf,1)
            if workspace.total_support(wi) >= p.thresholds.total_support_final
                % was UserData.handles(end+1) = 
                h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_final);
            else
                % was UserData.handles(end+1) = 
                h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_provisional);
            end
        end

        
        
    %% then draw the text ( so boxes don't cover text )
    
        for wi = 1:size(workspace.boxes_r0rfc0cf,1)
            
            label_text = workspace.labels{wi};
            
            x_position = workspace.boxes_r0rfc0cf(wi,3);
            y_position = workspace.boxes_r0rfc0cf(wi,1);
            
            t1 = text( x_position, y_position, label_text);
            set(t1,'color',[0 0 0]);
            set(t1,'FontSize',font_size);
            set(t1,'FontWeight','bold');
            t2 = text( x_position+1, y_position+1, label_text);
            set(t2,'color',[1 1 1]);
            set(t2,'FontSize',font_size);
            set(t2,'FontWeight','bold');
            
            h(end+1) = t1;
            h(end+1) = t2;
            
            detailed_text = {...
                workspace.labels{wi}; ...
                ['  int: ' num2str(workspace.internal_support(wi))]; ...
                ['  ext: ' num2str(workspace.external_support(wi))]; ...
                ['  tot: ' num2str(workspace.total_support(wi))]; ...
                ['  gt : ' num2str(workspace.GT_IOU(wi))]};
            
            x_position = workspace.im_size(2)+10;
            
            y_positions = linspace( 1, workspace.im_size(1), length(p.situation_objects)+2 );
            y_positions = y_positions(2:end-1);
            
            %y_position = workspace.boxes_r0rfc0cf(wi,1);
            y_position = y_positions(find(strcmp(workspace.labels{wi},p.situation_objects)));
            
            t3 = text( x_position, y_position, detailed_text);
            set(t1,'color',[0 0 0]);
            set(t1,'FontSize',font_size);
            set(t1,'FontWeight','bold');
            
            h(end+1) = t3;
            
        end
        hold off;

        
        
end
