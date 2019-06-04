function MultiCamLive
  A = load('CamData.mat'); % Load Calibraion Points
  Main = load('MainData.mat'); % Load Main Global Variables
  CamNum = Main.NumberOfCamerasInArray;
  XWidth = Main.ResolutionOfCameraWidth;
  YHeight = Main.ResolutionOfCameraHeight;
  
  Depth = 0;   % Default Depth Value
  
  loopRunning = true; % Is the video playing?
  DepthChanged = true; % Did you just change the Depth? (changes to false after first frame)
  FPSTOTAL = 0;
  z = 130; % frame variable % Specify start frame(time)
  zt = 0; % frame counter (will only increase by 1 even if user jumps ahead 30 frames) 
          % needed for FPS and Pause Delay Jumper
  
  % Setting Image Size for translation matrix
  xdata=[1 XWidth];
  ydata=[1 YHeight];
  
  % Gamma Correction for our Imagine RIT Setup (Change 0.5 to 1 for the Lab)
  lut = uint8(((0:255)/255.0).^0.5 * 255);
  
  for i = 1:CamNum
      % Generate the Calibration data from a base set of points in realtion
      % to all other point (Current Base = 3)
      TFORM(i) = cp2tform(A.CamData(:,:,i),A.CamData(:,:,3),'affine');
  end
  
  %% ------------------ Create Figure ---------------------%
  
  hFigure = figure('Position',[0 0 1040 720],...    % Create a figure window
                   'MenuBar','none','Renderer','OpenGL','Resize','off');
  
  MainAxes = axes('Parent', hFigure, 'Units', 'pixels',...   % Create the Axis to display images on
                  'Position', [1 1 960 720], 'Visible', 'off');
              
  CurrentFrame = uicontrol('Style','text','String','Current Frame',...   % Create text that displays current frame
                           'Position',[962 430 80 20],...
                           'HorizontalAlignment','Center','FontSize',10);
  uicontrol('Style','pushbutton',...  % Create Jump to Live Button
            'Position',[962 450 80 40],'String','LIVE',...
            'HorizontalAlignment','center','Callback',@jump_live);    
              
  uicontrol('Style','pushbutton',...  % Create the Up button #2
            'Position',[962 370 80 60],'String','^ Furth10 ^',...
            'HorizontalAlignment','center','Callback',@up_button10);                    
  uicontrol('Style','pushbutton',...  % Create the Up button
            'Position',[962 310 80 60],'String','^ Further ^',...
            'HorizontalAlignment','center','Callback',@up_button);      
  depthtext = uicontrol('Style','text','String','1','Position',[978 270 50 20],... % Depth Display
                        'HorizontalAlignment','center','FontSize',15);
  uicontrol('Style','pushbutton',...  % Create the Down button
            'Position',[962 190 80 60],'String','v Closer v',...
            'HorizontalAlignment','center','Callback',@down_button);
  uicontrol('Style','pushbutton',...  % Create the Down button #2
            'Position',[962 130 80 60],'String','v Clos10 v',...
            'HorizontalAlignment','center','Callback',@down_button10);         
  
  uicontrol('Style','text','String','FPS','Position',[972 105 60 20],... % FPS Static Text
                    'HorizontalAlignment','Left','FontSize',15);
  text2 = uicontrol('Style','text','String','FPS','Position',[972 85 60 20],... % FPS Display
                    'HorizontalAlignment','Left','FontSize',15);
  uicontrol('Style','text','String','AVERAGE','Position',[972 65 60 13],... % Average Static Text
                    'HorizontalAlignment','Left','FontSize',10);
  text3 = uicontrol('Style','text','String','AVERAGE','Position',[972 45 60 20],... % FPS AVE Display
                    'HorizontalAlignment','Left','FontSize',15);
                
  uicontrol('Style','pushbutton',...  % Create the Fast Forward Button
                         'Position',[962 0 40 40],'String','>>>','FontSize',10,...
                         'HorizontalAlignment','center','Callback',@forward_button);
  uicontrol('Style','pushbutton',...  % Create the Stop Button
                         'Position',[1002 0 40 40],'String','STOP','FontSize',8,...
                         'HorizontalAlignment','center','Callback',@stop_button);
  set(depthtext, 'String', num2str(Depth));   % Update the Default Text Value

  %% ------------------------------------------------------%
  %----------------------- Start SAP ----------------------%
  %--------------------------------------------------------%
  
  while loopRunning == true  
    fpsStart = tic; % Start Frame Timer
  
    % Preallocate the memory for your image canvas (needs to be preallocated
    % everytime in order to clear the matrix for the next frame)
    AllPics = zeros(YHeight,XWidth,'uint16');
    if DepthChanged == true
      % Will Empty the "brightness" array when depth is changed
      AllPics2 = zeros(YHeight,XWidth,'uint16');
    end
    
    %% -------------------- Render 1 Depth -------------------------%
    %------------------- Transform And Add Images ------------------%
    for i = 1:CamNum
      % Load Frame(z) from every Camera(i)
      gotImage = false; % Have you loaded the frame yet?
      Filename = sprintf('/home/share/camera%d_frame%06d.jpg',i,z);
      
      %% Used when the software runs faster than images are captured
      while gotImage == false
        while (~exist(Filename, 'file')) % If frame doesn't yet exist, wait .05 seconds
          pause(0.05);
        end
        % Try it again, sometimes it still doesn't exist so wait a little longer
        try
          ImgArray = imread(Filename); 
        catch exception
           pause(0.08);
           continue;
        end
        gotImage = true; % The frame exists, load it in and do your stuff.
      end
      
      %% Transform each camera's frame
      % M:Affine Transform Matrix, Adjust each camera based on center camera
      CamShift = [0 0 0; 0 0 0; (((CamNum+1)/2)-i)*Depth 0 0];
      CalibMatrix = getfield(getfield(TFORM(i), 'tdata'), 'T'); % get the tansform matrix from 'cp2tform' calibration
      ABC = CalibMatrix + CamShift; % Add the camera shift and the calibration together
      R = maketform('affine', ABC); % tells the software that this is an affine transformation
      W = imtransform(ImgArray, R, 'nearest', 'XData', xdata, 'YData', ydata);   % Transforming each image (W = output)
      
      if DepthChanged == true % If you've changed the depth, move the brightness corrector array too
        % Figures out how many images overlap at what points and creates
        % numbers to divide by
        G = imtransform(ones(YHeight,XWidth,'uint8'), R, 'nearest', 'XData', xdata, 'YData', ydata);
        AllPics2 = AllPics2 + uint16(G); % Add each new camera
      end
     
      AllPics = AllPics + uint16(W);   % Add each camera image together to create one frame at one depth
    end
    DepthChanged = false;
    % Show the final image, reconverted to 8bits,corrected for gamma, and
    % divded correctly for brightness ("./" = divide two images)
    imshow(lut(uint8(AllPics./AllPics2 + 1)) ,'Parent',MainAxes);
    %% --------------------------------------------------------------%
    
    fpsEnd = toc(fpsStart); % Ends frame timer and converts it to Frames per Second
    
    pause(0.001); % Need a 1 millisecond delay or the 'while' loop will complete before displaying any frames
   
    z = z + 1; % increases the frame
    zt = zt + 1; % increase the frame counter   
    
    if mod(zt,200) == 0  %divides by 200, looks for remainder of 0
      z = z + 1; % Jumps one extra frame every 200 frames to make up for the 1 millisecond 'pause' 
    end
    
    if loopRunning == false
      break  % Breaks the While loop so that no errors will display when the system closes
    end
    
    FPS = 1/fpsEnd; % Calculates the FPS 
    FPSTOTAL = FPSTOTAL + (FPS); % Add each FPS together to get a total
    set(text2, 'String', num2str(FPS)); % Updates FPS Display
    set(text3, 'String', num2str(FPSTOTAL/(zt))); % Updates FPS Average Display
    set(CurrentFrame,'String',num2str(z));
  end
  %% ^^ Program End ^^ %%
  
  %% Button Callback Functions (aka Event Listeners)
  
  %----------- Up Buttons ------------%
  function up_button(hObject,eventData)
    Depth = Depth - 1;   % Subtracts 1 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth)); % Update the Default Text Value
  end
  function up_button10(hObject,eventData) 
    Depth = Depth - 10;   % Subtracts 10 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end

  %----------- Down Buttons ------------%
  function down_button(hObject,eventData)
    Depth = Depth + 1;   % Adds 1 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end
  function down_button10(hObject,eventData)  
    Depth = Depth + 10;   % Adds 10 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end
  
  %-------- Forward/Stop Buttons  ---------%
  function forward_button(hObject,eventData)
    z = z + 1; % Jumps the frame counter 1 ahead in case of program lag in real time
    set(CurrentFrame,'String',num2str(z));
  end
  function stop_button(hObject,eventData)
    loopRunning = false; % Kills Loop
    disp('Closed');
    close all % Closes Figure
    clear all % Clears the Workspace Variables etc...
    return % Kills Main Function
  end
  
  %-------- Other Fuctions -----------%
  function jump_live(hObject,eventData)
  dirlist = dir('/home/share/*.jpg'); % Count how many images are in the share folder
  NewestFrame = floor(length(dirlist)/CamNum)-7; % Divde by CamNum and Subtract 7 to be safe
    z = NewestFrame; 
  end

end