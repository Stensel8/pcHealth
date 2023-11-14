namespace pcHealthPlus_VS
{
    partial class toolForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(toolForm));
            this.toolsMenu2 = new System.Windows.Forms.MenuStrip();
            this.quitToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.helpMenuButton = new System.Windows.Forms.ToolStripMenuItem();
            this.aboutToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.gitHubToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.menuToolStripMenuItem2 = new System.Windows.Forms.ToolStripMenuItem();
            this.mainToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.programsToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.labelTimer2 = new System.Windows.Forms.Timer(this.components);
            this.timeLabel2 = new System.Windows.Forms.Label();
            this.toolsMenu2.SuspendLayout();
            this.SuspendLayout();
            // 
            // toolsMenu2
            // 
            this.toolsMenu2.BackColor = System.Drawing.Color.White;
            this.toolsMenu2.Font = new System.Drawing.Font("Bahnschrift", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.toolsMenu2.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.quitToolStripMenuItem,
            this.helpMenuButton,
            this.aboutToolStripMenuItem,
            this.menuToolStripMenuItem2});
            this.toolsMenu2.Location = new System.Drawing.Point(0, 0);
            this.toolsMenu2.Name = "toolsMenu2";
            this.toolsMenu2.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.toolsMenu2.Size = new System.Drawing.Size(933, 27);
            this.toolsMenu2.TabIndex = 1;
            this.toolsMenu2.Text = "Menu2";
            // 
            // quitToolStripMenuItem
            // 
            this.quitToolStripMenuItem.Font = new System.Drawing.Font("Bahnschrift SemiBold", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.quitToolStripMenuItem.Name = "quitToolStripMenuItem";
            this.quitToolStripMenuItem.Size = new System.Drawing.Size(50, 23);
            this.quitToolStripMenuItem.Text = "&Quit";
            this.quitToolStripMenuItem.Click += new System.EventHandler(this.quitToolStripMenuItem_Click);
            // 
            // helpMenuButton
            // 
            this.helpMenuButton.Font = new System.Drawing.Font("Bahnschrift SemiBold", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.helpMenuButton.Name = "helpMenuButton";
            this.helpMenuButton.Size = new System.Drawing.Size(55, 23);
            this.helpMenuButton.Text = "&Help";
            this.helpMenuButton.Click += new System.EventHandler(this.helpMenuButton_Click);
            // 
            // aboutToolStripMenuItem
            // 
            this.aboutToolStripMenuItem.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.gitHubToolStripMenuItem});
            this.aboutToolStripMenuItem.Font = new System.Drawing.Font("Bahnschrift SemiBold", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.aboutToolStripMenuItem.Name = "aboutToolStripMenuItem";
            this.aboutToolStripMenuItem.Size = new System.Drawing.Size(63, 23);
            this.aboutToolStripMenuItem.Text = "&About";
            // 
            // gitHubToolStripMenuItem
            // 
            this.gitHubToolStripMenuItem.Name = "gitHubToolStripMenuItem";
            this.gitHubToolStripMenuItem.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.gitHubToolStripMenuItem.Size = new System.Drawing.Size(180, 24);
            this.gitHubToolStripMenuItem.Text = "&GitHub";
            this.gitHubToolStripMenuItem.Click += new System.EventHandler(this.gitHubToolStripMenuItem_Click);
            // 
            // menuToolStripMenuItem2
            // 
            this.menuToolStripMenuItem2.DropDownItems.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.mainToolStripMenuItem,
            this.programsToolStripMenuItem});
            this.menuToolStripMenuItem2.Font = new System.Drawing.Font("Bahnschrift SemiBold", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.menuToolStripMenuItem2.Name = "menuToolStripMenuItem2";
            this.menuToolStripMenuItem2.Size = new System.Drawing.Size(60, 23);
            this.menuToolStripMenuItem2.Text = "&Menu";
            this.menuToolStripMenuItem2.Click += new System.EventHandler(this.menuToolStripMenuItem2_Click);
            // 
            // mainToolStripMenuItem
            // 
            this.mainToolStripMenuItem.Name = "mainToolStripMenuItem";
            this.mainToolStripMenuItem.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.mainToolStripMenuItem.Size = new System.Drawing.Size(180, 24);
            this.mainToolStripMenuItem.Text = "&Main";
            this.mainToolStripMenuItem.TextDirection = System.Windows.Forms.ToolStripTextDirection.Horizontal;
            this.mainToolStripMenuItem.Click += new System.EventHandler(this.mainToolStripMenuItem_Click);
            // 
            // programsToolStripMenuItem
            // 
            this.programsToolStripMenuItem.Name = "programsToolStripMenuItem";
            this.programsToolStripMenuItem.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.programsToolStripMenuItem.Size = new System.Drawing.Size(180, 24);
            this.programsToolStripMenuItem.Text = "&Programs";
            this.programsToolStripMenuItem.TextDirection = System.Windows.Forms.ToolStripTextDirection.Horizontal;
            this.programsToolStripMenuItem.Click += new System.EventHandler(this.programsToolStripMenuItem_Click);
            // 
            // labelTimer2
            // 
            this.labelTimer2.Enabled = true;
            this.labelTimer2.Tick += new System.EventHandler(this.timeLabel2_Timer);
            // 
            // timeLabel2
            // 
            this.timeLabel2.AutoSize = true;
            this.timeLabel2.BackColor = System.Drawing.Color.White;
            this.timeLabel2.Font = new System.Drawing.Font("Bahnschrift", 14.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.timeLabel2.Location = new System.Drawing.Point(12, 4);
            this.timeLabel2.Name = "timeLabel2";
            this.timeLabel2.Size = new System.Drawing.Size(110, 23);
            this.timeLabel2.TabIndex = 2;
            this.timeLabel2.Text = "systemTime";
            this.timeLabel2.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            this.timeLabel2.Click += new System.EventHandler(this.timeLabel2_Load);
            // 
            // toolForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.BackColor = System.Drawing.Color.Silver;
            this.ClientSize = new System.Drawing.Size(933, 554);
            this.Controls.Add(this.timeLabel2);
            this.Controls.Add(this.toolsMenu2);
            this.Font = new System.Drawing.Font("Bahnschrift", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Margin = new System.Windows.Forms.Padding(4);
            this.Name = "toolForm";
            this.Text = "pcHealthPlus | Tools";
            this.Load += new System.EventHandler(this.toolForm_Load);
            this.toolsMenu2.ResumeLayout(false);
            this.toolsMenu2.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion
        private System.Windows.Forms.MenuStrip toolsMenu2;
        private System.Windows.Forms.ToolStripMenuItem quitToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem helpMenuButton;
        private System.Windows.Forms.ToolStripMenuItem aboutToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem gitHubToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem menuToolStripMenuItem2;
        private System.Windows.Forms.ToolStripMenuItem mainToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem programsToolStripMenuItem;
        private System.Windows.Forms.Timer labelTimer2;
        private System.Windows.Forms.Label timeLabel2;
    }
}