


function [salience_r, salience] = hmaxq_salience( model, image )

    % [salience_r,salience] = hmaxq_salience( model, image );
    % returns a general salience map using parameters from model
    % use hmaxq_initialize_model to see the options
    %
    % salience_r is the size of the input image
    % salience is the size used during generation

    temp = hmaxq_im2c1(model,image);
    salience_r = temp.salience_r;
    salience = temp.salience;
    
end







