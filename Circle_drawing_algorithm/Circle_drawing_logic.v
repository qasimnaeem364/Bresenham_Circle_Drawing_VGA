module Circle_drawing_logic (KEY, CLOCK_50, SW, VGA_R, VGA_G, VGA_B,
VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

	parameter xc = 80, yc = 60; //center for circles 
	parameter BLK = 3'b000; //reset screen color 

	input [1:0] KEY; // input KEYs 
	input [9:0] SW; // inputs to get radius SW[3:8] and for colout SW[2:0]
	input CLOCK_50;
   wire CLK50;
   assign CLK50 = CLOCK_50;	
	wire RST = KEY[0]; //key[0] to trigger Reset 
	wire [5:0] RAD = (SW[8:3]>59)? 59:SW[8:3]; //radius hardwire to 59 if input is greater than 59 
	wire str; //interupt to draw circle 
	wire clr_in;
	assign clr_in = SW [2:0]; //colour of the circle
	
	assign str = KEY[1];
	//outputs to drive the VGA_controller 
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK_N;
	output VGA_SYNC_N;
	output VGA_CLK;
	output [9:0] VGA_R; //as DE_SoC have 8 bit DAC
	output [9:0] VGA_G;
	output [9:0] VGA_B;

	
	reg [7:0] x;
	reg [6:0] y;
	reg fg;   //column_flag when coloumn reaches 119
	reg row_fg; // row flag when row reaches 159
	
	//used to implement algorithm xr,yr and d
	reg [7:0] xr;
	reg [6:0] yr;
	reg signed [8:0] d;
	reg blank_fg; //when the screen is resetted to black
	reg [2:0] COLOR;
	reg draw; //signal to drive in different states 
	
	//VGA_adapter to drive VGA outputs 
	
	vga_adapter VGA(
			.resetn(RST),
			.clock(CLK50),
			.colour(COLOR),
			.x(x),
			.y(y),
			.plot(draw),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
			//parameters
			
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "image.colour.mif";
	
	
	reg [3:0]	STATE;
//State declaration
	parameter RESET = 0, BLANK = 1, INITIAL = 2,STOP = 3,
				 STATE1 = 4,
				 STATE2 = 5,
				 STATE3 = 6,
				 STATE4 = 7,
				 STATE5 = 8,
				 STATE6 = 9,
				 STATE7 = 10,
				 STATE8 = 11;

//this determines the next state
	always @ (posedge CLK50 or negedge RST) begin
		if (~RST)
			STATE <= RST;  //reset state 
			
		else
			case (STATE)
				RESET:
				begin
					STATE <= BLANK; 	
				end
					
				BLANK: //state to set all pixels of LCD to black
				begin
					if (blank_fg) // goes to IDLE state when done
						STATE <= STOP;
					else					
						STATE <= BLANK;	
				end
					
				STOP:
				begin
					if ((xr <= yr) & ~str) //checks if circle draw interupt is pressed 
						STATE <= INITIAL;
					else
						STATE <= STOP;
				end
				
				INITIAL: //starts the Bresenham’s circle drawing algorithm 
				begin
					STATE <= STATE1;
				end
				
				STATE1: STATE <= STATE2;
				STATE2: STATE <= STATE3;
				STATE3: STATE <= STATE4;
				STATE4: STATE <= STATE5;
				STATE5: STATE <= STATE6;
				STATE6: STATE <= STATE7;
				STATE7: STATE <= STATE8;
				STATE8: 
				begin
					if (xr > yr) //all according to Bresenham’s circle drawing algorithm
						STATE <= STOP;
					else
						STATE <= STATE1;
				end
				
				default: STATE <= RESET;
				
			endcase
	end
	
	
	//outputs and control signals
	
	always @ (posedge CLK50) begin
	
		row_fg <= x / 159; // rows pixel check 
		
		case (STATE)
		RESET:
		begin
		  //initializing control signals and outputs to zero
			fg <= 0;
			row_fg <= 0;
			blank_fg <= 0;
			x <= 0;
			y <= 0;
			draw <= 0;
			
			//loading initial values 
			xr <= 0;
			yr <= RAD;
			d <= 3 - 2*RAD;
		end
		
		BLANK: //state to set all pixels to black ( reset state)
		begin
			x <= (x + 1) % 160;
			draw <= 1;
			COLOR <= BLK;
			
			if (row_fg)
			begin
				y <= (y + 1) % 120;
				blank_fg <= y / 119;
			end
		end
		
		STOP: //IDLE state 
		begin
			draw <= 0;
			xr <= 0;
			yr <= RAD;
			d <= 3 - 2*RAD;
			COLOR <= SW [2:0];
		end
		
		
		INITIAL:
		begin
		//initializes values 
			xr <= 0;
			yr <= RAD;
			d <= 3 - 2*RAD;
			draw <= 0;
			COLOR <= SW[2:0]; //colour of the circle
		end
		
	//now algorithm starts 
	
		STATE1:
		begin
			draw <= 1;
			x <= xc + xr;
			y <= yc + yr;
		end
		
		STATE2:
		begin
			draw <= 1;
			x <= xc - xr;
			y <= yc + yr;
		end
		
		STATE3:
		begin
			draw <= 1;
			x <= xc + xr;
			y <= yc - yr;
		end
		
		STATE4:
		begin
			draw <= 1;
			x <= xc - xr;
			y <= yc - yr;
		end
		
		STATE5:
		begin
			x <= xc + yr;
			y <= yc + xr;
		end
		
		STATE6:
		begin
			draw <= 1;
			x <= xc - yr;
			y <= yc + xr;
		end
		
		STATE7:
		begin
			draw <= 1;
			x <= xc + yr;
			y <= yc - xr;
		end
		
		STATE8: //this is the last state which checks if the cirlce has been drawn or not
		begin
			draw <= 1;
			x <= xc - yr;
			y <= yc - xr;
			xr <= xr + 1;
			
			if (d<0)
				d <= d+4*xr+6;
			else
			begin
				d <= d + 4*(xr-yr)+10;
				yr <= yr -1;
			end
		end
		
		endcase
		
	end

endmodule

// ALGORITHM IMPLMENTED 

/*function circle_bresenham ( xc , yc , r )
x := 0
y := r
d := 3-2*r
loop
if x > y exit loop
setPixel (xc + x, yc + y)
setPixel (xc - x, yc + y)
setPixel (xc + x, yc - y)
setPixel (xc - x, yc - y)
setPixel (xc + y, yc + x)
setPixel (xc - y, yc + x)
setPixel (xc + y, yc - x)
 setPixel (xc - y, yc - x)
x := x + 1
if d < 0 then
d := d + (4 * x) + 6
else
d := d + 4 * (x – y) + 10
y := y – 1
end if-else
end loop
end function
*/