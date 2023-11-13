namespace pcHealthPlus_VS
{
    partial class copyrightForm
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
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(copyrightForm));
            this.pictureBox1 = new System.Windows.Forms.PictureBox();
            this.learnMoreLabel = new System.Windows.Forms.Label();
            this.learnMoreLinkLabel = new System.Windows.Forms.LinkLabel();
            ((System.ComponentModel.ISupportInitialize)(this.pictureBox1)).BeginInit();
            this.SuspendLayout();
            // 
            // pictureBox1
            // 
            this.pictureBox1.Image = ((System.Drawing.Image)(resources.GetObject("pictureBox1.Image")));
            this.pictureBox1.Location = new System.Drawing.Point(-2, 0);
            this.pictureBox1.Name = "pictureBox1";
            this.pictureBox1.Size = new System.Drawing.Size(322, 178);
            this.pictureBox1.TabIndex = 0;
            this.pictureBox1.TabStop = false;
            this.pictureBox1.Click += new System.EventHandler(this.pictureBox1_Click);
            // 
            // learnMoreLabel
            // 
            this.learnMoreLabel.AutoSize = true;
            this.learnMoreLabel.BackColor = System.Drawing.Color.Transparent;
            this.learnMoreLabel.ForeColor = System.Drawing.Color.Transparent;
            this.learnMoreLabel.Location = new System.Drawing.Point(184, 126);
            this.learnMoreLabel.Name = "learnMoreLabel";
            this.learnMoreLabel.Size = new System.Drawing.Size(0, 16);
            this.learnMoreLabel.TabIndex = 1;
            this.learnMoreLabel.Click += new System.EventHandler(this.learnMoreLabel_Click);
            // 
            // learnMoreLinkLabel
            // 
            this.learnMoreLinkLabel.AutoSize = true;
            this.learnMoreLinkLabel.BackColor = System.Drawing.Color.Transparent;
            this.learnMoreLinkLabel.BorderStyle = System.Windows.Forms.BorderStyle.Fixed3D;
            this.learnMoreLinkLabel.Location = new System.Drawing.Point(184, 126);
            this.learnMoreLinkLabel.Name = "learnMoreLinkLabel";
            this.learnMoreLinkLabel.Size = new System.Drawing.Size(77, 18);
            this.learnMoreLinkLabel.TabIndex = 2;
            this.learnMoreLinkLabel.TabStop = true;
            this.learnMoreLinkLabel.Text = "Learn more";
            this.learnMoreLinkLabel.Click += new System.EventHandler(this.learnMoreLinkLabel_onClick);
            // 
            // copyrightForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(319, 177);
            this.Controls.Add(this.learnMoreLinkLabel);
            this.Controls.Add(this.learnMoreLabel);
            this.Controls.Add(this.pictureBox1);
            this.Font = new System.Drawing.Font("Bahnschrift", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Margin = new System.Windows.Forms.Padding(4);
            this.Name = "copyrightForm";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
            this.Text = "pcHealthPlus | Copyright";
            this.Load += new System.EventHandler(this.copyrightForm_Load);
            ((System.ComponentModel.ISupportInitialize)(this.pictureBox1)).EndInit();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.PictureBox pictureBox1;
        private System.Windows.Forms.Label learnMoreLabel;
        private System.Windows.Forms.LinkLabel learnMoreLinkLabel;
    }
}